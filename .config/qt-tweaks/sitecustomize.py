# Loaded into Dangerzone at start: files are picked with yazi, and Vim keys (j k h l, gg G,
# Ctrl+d / Ctrl+u; s presses "Select suspicious documents…" or "Convert to Safe Document")
import importlib.abc
import importlib.util
import sys


def _vim_keys(app):
    from PySide6 import QtCore, QtGui, QtWidgets

    Qt, QEvent = QtCore.Qt, QtCore.QEvent
    W = QtWidgets
    lists = (W.QAbstractItemView, W.QAbstractScrollArea)

    def typing(w):
        if isinstance(w, (W.QTextEdit, W.QPlainTextEdit)):
            return not w.isReadOnly()
        if isinstance(w, W.QComboBox):
            return w.isEditable()
        return isinstance(w, (W.QLineEdit, W.QAbstractSpinBox, W.QKeySequenceEdit))

    # the buttons s presses (the first one on screen)
    s_buttons = ("select suspicious document", "convert to safe document")

    def press_s(window):
        if window is None:
            return False
        shown = [b for b in window.findChildren(W.QPushButton) if b.isVisible() and b.isEnabled()]
        for want in s_buttons:
            for b in shown:
                if b.text().replace("&", "").strip().lower().startswith(want):
                    b.click()
                    return True
        return False

    def send(w, key, mods=Qt.NoModifier):
        for kind in (QEvent.KeyPress, QEvent.KeyRelease):
            QtWidgets.QApplication.sendEvent(w, QtGui.QKeyEvent(kind, key, mods))

    class Keys(QtCore.QObject):
        last_g = 0.0

        def eventFilter(self, obj, ev):
            app = QtWidgets.QApplication
            if ev.type() != QEvent.KeyPress or obj is not (app.focusWidget() or app.activeWindow()) or typing(obj):
                return False
            text, mods = ev.text(), ev.modifiers() & ~Qt.KeypadModifier
            if text == "s" and mods == Qt.NoModifier:
                return press_s(obj.window())
            in_list = isinstance(obj, lists)
            ctrl = mods == Qt.ControlModifier
            if ctrl and ev.key() in (Qt.Key_D, Qt.Key_U):
                key = Qt.Key_PageDown if ev.key() == Qt.Key_D else Qt.Key_PageUp
            elif mods not in (Qt.NoModifier, Qt.ShiftModifier) or not text:
                return False
            elif text == "j":
                key = Qt.Key_Down if in_list else Qt.Key_Tab
            elif text == "k":
                if not in_list:
                    send(obj, Qt.Key_Backtab, Qt.ShiftModifier)
                    return True
                key = Qt.Key_Up
            elif text in ("h", "l"):
                key = Qt.Key_Left if text == "h" else Qt.Key_Right
            elif text == "G":
                key = Qt.Key_End
            elif text == "g":
                now = QtCore.QDateTime.currentMSecsSinceEpoch()
                if now - self.last_g > 800:
                    self.last_g = now
                    return True
                self.last_g = 0.0
                key = Qt.Key_Home
            else:
                return False
            if not in_list and key in (Qt.Key_Home, Qt.Key_End, Qt.Key_PageDown, Qt.Key_PageUp):
                return False
            send(obj, key)
            return True

    app._vim_keys = Keys(app)
    app.installEventFilter(app._vim_keys)


def _patch_app(app_class):
    from PySide6 import QtDBus

    start = app_class.__init__

    def __init__(self, *args, **kwargs):
        start(self, *args, **kwargs)
        try:
            _vim_keys(self)
        except Exception:
            pass
        msg = QtDBus.QDBusMessage.createMethodCall(
            "org.freedesktop.portal.Desktop", "/org/freedesktop/portal/desktop",
            "org.freedesktop.DBus.Properties", "Get")
        msg.setArguments(["org.freedesktop.portal.FileChooser", "version"])
        QtDBus.QDBusConnection.sessionBus().call(msg, QtDBus.QDBus.Block, 1000)
        for _ in range(3):
            self.processEvents()

    app_class.__init__ = __init__


def _patch_dangerzone(module):
    import os

    from PySide6 import QtCore

    cls = getattr(module, "SettingsWidget", None)
    if cls is None or not hasattr(cls, "select_output_directory"):
        return
    home = os.path.expanduser("~")

    def show_dir(self):
        path = str(self.dangerzone.output_dir)
        text = "~" + path[len(home):] if path == home or path.startswith(home + "/") else path
        box = self.save_location
        box.setText(text)
        box.setToolTip(path)
        box.setMinimumWidth(min(420, box.fontMetrics().horizontalAdvance(text) + 24))
        box.setCursorPosition(len(text))
        return text

    def flash(box):
        old = box.styleSheet()
        box.setStyleSheet(old + "QLineEdit { border: 2px solid palette(highlight); font-weight: bold; }")
        QtCore.QTimer.singleShot(1800, lambda: box.setStyleSheet(old))

    choose, added = cls.select_output_directory, getattr(cls, "documents_added", None)

    def select_output_directory(self):
        before, picked = str(self.dangerzone.output_dir), []
        settings = getattr(self.dangerzone, "settings", None)
        real_set = getattr(settings, "set", None)
        if real_set is not None:
            def watch(key, value, *args, **kwargs):
                if key == "output_dir":
                    picked.append(value)
                return real_set(key, value, *args, **kwargs)
            settings.set = watch
        try:
            choose(self)
        finally:
            if real_set is not None:
                del settings.set
        try:
            show_dir(self)
            if picked or str(self.dangerzone.output_dir) != before:
                self.radio_save_to.setChecked(True)
                flash(self.save_location)
        except Exception:
            pass

    def documents_added(self, *args, **kwargs):
        added(self, *args, **kwargs)
        try:
            show_dir(self)
        except Exception:
            pass

    cls.select_output_directory = select_output_directory
    if added is not None:
        cls.documents_added = documents_added


_PATCHES = {"PySide6.QtWidgets": lambda m: _patch_app(m.QApplication),
            "dangerzone.gui.main_window": _patch_dangerzone}


class _Finder(importlib.abc.MetaPathFinder):
    busy = False

    def find_spec(self, name, path, target=None):
        if name not in _PATCHES or self.busy:
            return None
        self.busy = True
        try:
            spec = importlib.util.find_spec(name)
        finally:
            self.busy = False
        patch = _PATCHES.pop(name)
        if not _PATCHES:
            sys.meta_path.remove(self)
        if spec is None or spec.loader is None:
            return spec
        load = spec.loader.exec_module

        def exec_module(module):
            load(module)
            try:
                patch(module)
            except Exception:
                pass

        spec.loader.exec_module = exec_module
        return spec


sys.meta_path.insert(0, _Finder())
