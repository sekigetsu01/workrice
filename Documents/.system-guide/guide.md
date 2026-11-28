# Your system
> Every feature, key and tool, by section. Keys are in green; Super is the Windows key.

## How it all fits together

> How the system fits together, the keys to learn first, and where things live.

### The pieces

| System | Arch Linux with the **mango** tiling desktop
| Shell | A self-built **Quickshell**: the launcher, panels, notifications, lock screen and the top bar
| Colours | From the wallpaper, everywhere (pywal; the browser follows through Pywalfox). Except the meaning colours in the bar and panels: green, red and orange are always green, red and orange (good, bad, careful), in the wallpaper's own tone so they sit among its colours; critical pop-ups are red
| A new wallpaper | Its colours are ready at once (wallpaper warm works them out ahead of time, in the background: at login, when the selector opens, after each change). A colour too dark to read on the background is lightened just enough (same hue)
| What changes with it | Open apps, no restart: the bar and panels, window borders, terminals (and yazi, Books and kp in them), Neovim, sioyek, btop, mpv, Glide, Vesktop and swayimg; fzf in open shells from the next prompt. GTK and Qt apps keep their own colours
| Keys | Almost everything is keyboard-driven, with vim-style keys. **Super** is the Windows key

### The keys to learn first

| Super+Return | Terminal
| Super+d | App launcher (type to search, Enter to open)
| Super+w / Super+r / Super+s | Browser (Glide) / files (yazi) / PDF reader (sioyek)
| Super+q | Close the window
| Super+1 … 9 | Go to workspace 1–9 (Super+Tab: back to the last one)
| Super+p | Screenshot tool
| Super+Shift+m or Play key | Pause everything playing (audio, video); press again to resume
| Super+BackSpace | Power menu: lock, reboot, shut down
| ? (in Glide) | Show that app's key list
| Super+F9 | Open this guide (System Guide.pdf in ~/Documents)

### Where things live

| ~/sync/documents, ~/sync/notes | Documents; notes wiki (vimwiki)
| ~/Documents | This guide (System Guide.pdf; its source is in ~/Documents/.system-guide)
| ~/wallpapers (night/ subfolders) | Wallpapers; night/ ones are used at night (another folder can be picked in the wallpaper selector)
| ~/.config/wal | How the wallpaper's colours are written into every app's format (templates/, into ~/.cache/wal, by pywal when the wallpaper script runs it) and what's refreshed after (postrun)
| ~/.config/times.conf | All timings: night switch, night mode (red screen and dimming), pomodoro (edit with settimes)
| ~/Downloads, ~/Videos, ~/Pictures/Screenshots | Downloads, screen recordings, screenshots (yt and yta download into the folder you're in)

## Desktop: mango window manager

> mango arranges the windows for you. Keys for apps, windows and workspaces, and what starts at login.

### How windows behave

| Tiling | The newest window goes in the big 'master' area on the left (58% of the screen); the rest stack on the right
| Workspaces | Called tags (1–9)
| Focus | Follows the mouse; the cursor jumps to the window you pick with the keyboard and hides when idle
| Keyboard | UK layout, fast key repeat, Num Lock on, Caps Lock is Esc (only on the desktop: at the disk passphrase and the login screen it is still Caps Lock)
| Touchpad | Natural scrolling (the page follows your fingers, like a phone); a mouse wheel scrolls the usual way
| The laptop's screen | Not scaled (scale 1): the bar and panels are drawn bigger by themselves (the panels 25%), and kitty has its own larger text
| Other monitors | Scaled so things look the same size as on the laptop, worked out from each screen's real size and how far away you sit (70 cm for an external monitor). An ultrawide gets more room with the same-looking text. Monitors plugged in later are scaled too (~/.config/mango/scripts/autoscale)
| A monitor too big or small | Put its name and a scale in ~/.config/mango/scale-overrides, one per line (e.g. DP-1 1.25): a set scale always wins
| Any screen size | Each monitor is scaled to look like this one (800 pixels tall): the bar, panels, terminals and apps keep the same proportions on a 1080p laptop (1.375), a 1440p or ultrawide monitor (1.75) or 4K (2.75). An ultrawide is matched by its height, so its extra width is more room. Monitors plugged in later are scaled too (~/.config/mango/scripts/autoscale)

### Open apps and tools

| Super+Return | Terminal (kitty)
| Super+d | App launcher
| Super+w | Glide browser
| Super+r | yazi file manager (a text file you open takes over its window in nvim)
| Super+s | sioyek PDF reader (another press opens another window)
| Super+e | Thunderbird (email)
| Super+n | Neovim on your notes wiki, in kitty (so its pictures show properly)
| Super+v | Vesktop (Discord); open already: it comes to the tag you're on. Discord's own look in the wallpaper's colours (~/.config/wal/vesktop-base.css, recoloured into its themes folder). Graphics acceleration and smooth scrolling are off (faster here, with no graphics card)
| Super+Shift+o | LibreOffice (a new Writer document)
| Super+f | Make the focused window as big as the screen, with the bar still showing (press again to undo)
| Super+Alt+f | Real fullscreen, hiding the bar (press again to leave)
| Super+Shift+f | FreeTube (another press opens another window)
| Super+Shift+r | btop system monitor
| Super+F4 | wiremix (audio mixer): h / l or a click / drag on a volume bar sets it; scrolling sideways over one (touchpad swipe, tilt wheel) changes it 1% a step; the up / down wheel moves through the list
| Super+F5 | Wifi menu (see Quickshell panels)
| Alt+b | Books: the audiobook player, shown / hidden (see Audiobooks)
| Alt+Shift+s | sioyek's last book, asking whether to open its note and audiobook with it (see Book, audiobook and note together). Again: closes that question
| Super+Shift+d | kp password manager: opens it, or hides / brings back the open one (it stays unlocked)
| Super+b | Random wallpaper (day or night); hold it to keep changing
| Super+u | VPN on / off: connects (vp) in a terminal on tag 9 while you stay where you are, fetching a fresh config first if the saved one is missing or about to run out. No password (the very first time a small window asks for it once)
| Super+Shift+s | Wallpaper selector
| Super+` (grave) | Emoji picker
| Super+' (apostrophe) | Calculator and unit/currency converter
| Super+F3 | Time zone picker
| Super+c | Calendar
| Alt+r | Reminders for today, in a floating Neovim (again: saves and closes it; open but not focused: brings it to you)
| Alt+a | Your plan in a floating Neovim: agenda, routines and to-dos (again: saves and closes it; open but not focused: brings it to you)
| Alt+BackSpace | Close the reminder on screen (that's it done); with no reminder showing, the newest pop-up
| Super+Shift+n | Notification center
| Super+BackSpace | Power menu
| Ctrl+Alt+l | Lock the screen
| Super+F9 | This guide

### Windows

| Super+q | Close the focused window, straight away (Neovim saves as it closes)
| Super+j / Super+k | Focus next / previous window
| Super+Shift+h j k l | Swap the window left / down / up / right
| Super+h / Super+l | Window narrower / wider (not Books: it keeps its size)
| Super+Space | Move the focused window into the master spot
| Super+i / Super+o | One more / one fewer window in the master area
| Super+t / Super+Shift+t / Super+Shift+c | Tile / vertical tile / grid layout
| Super+a | Gaps on / off
| Super+z / Super+x | Gaps bigger / smaller

### Workspaces (tags)

| Super+1 … 9 | Go to tag 1–9 (pressing the one you're on does nothing)
| Super+Shift+1 … 9 | Send the window to tag 1–9 and stay here
| Super+Tab | Back to the tag you were on before
| Super+g / Super+; | Tag to the left / right
| Super+Shift+g / Super+Shift+; | Send the window to the tag left / right
| Super+scroll | The tag to the left / right (up / down), empty or not

### Sound, media, screen

| Super+. / Super+, (or volume keys) | Volume up / down 5%
| Super+m (or mute key) | Mute on / off
| Brightness keys, or Super+Up / Super+Down | Screen brighter / darker, 10% a press
| Super+Right / Super+Left | Red screen (night light) stronger / weaker, 10% a step, any time of day (until the morning: night_end and dim_end turn it off); all the way down turns it off. A note shows the level
| Night mode | From 01:00 to 05:00 the screen goes 40% red and as dark as it goes; at 06:00 it's back to full brightness (times in times.conf). Never straight after switching the laptop on: started after 01:00, the screen stays normal that night
| Super+= (or Super++) / Super+- | Terminals fully solid / back to see-through (the default); new terminals open the same way. kp is always solid
| Super+Shift+m (or Play key) | Pause all: pauses every player and remembers them (adding to any paused earlier); a press with nothing playing resumes them all
| Super+p | Screenshot tool
| Super+F1 | Start / stop screen recording (with desktop sound). While it records (not while paused), a red dot shows on the bar after the window's title
| Super+Shift+F1 | Record a region you draw
| Super+F2 | Pause / carry on recording
| Alt+p | Pomodoro: start / pause
| Alt+Shift+p | Pomodoro: reset (off)
| Super+F6 | Auto-clicker on / off
| Super+Shift+F6 | Set the auto-clicker's speed and button
| Super+F10 | Record a macro: name it (Enter for 'last'), the window hides, then everything you type, click and move the mouse to is recorded. Super+F10 again stops and saves it
| Super+F11 | Your macros, newest first, with each one's steps beside it. j/k move (nothing to type), Enter plays it once, Shift+Enter loops it forever, Shift+R asks how many times (5) or how long (30s, 10m, 1h), Shift+D deletes it
| While one plays | You see the pointer glide between points. Super+F11 again stops it. Holding Super pauses it and lets go of every key, so nothing it types turns into a shortcut; letting go carries on
| Super+Shift+F11 | Play the last macro again, once (again: stops it)
| Again | Any key that opens the clicker's window closes it on a second press
| clicker check | In a terminal: says what's stopping the clicker, if anything
| Next / previous keys | Next / previous track in any player
| Super+Alt+Shift+r | Reload the mango config (saving the file also reloads it)

### At login it starts

| Quickshell | Panels, notifications, lock screen, top bar
| Link cleaner | Removes tracking from links you copy
| Helpers | The previous-tag tracker for Super+Tab, the watcher that brings a window asking for attention (mm attention), a hidden kitty that new terminals open in (instant terminals), your timings from times.conf, and the screen scaling
| Timers | The night switch and night mode (times.conf), and the Downloads cleaner (scrub-downloads)
| wallpaper warm | Works out the colours of any wallpaper not seen yet, quietly, so changing wallpaper is instant

### Window behaviour

| Always floating | At a fixed size: kp, reminders and your plan (Alt+a; in the middle), clicker, Books and its pop-ups, bookset's questions, the VPN password window, the speak window, the mpv audio player and IOPaint. Reminders, your plan and IOPaint stay above other windows
| Windows come to you | Anything that brings up a window on another tag (kp, Books, Super+v, an app asking for attention) moves it onto the tag you're on, instead of taking you to its tag; a floating one (Books, kp…) comes back in the middle. The VPN terminal stays on tag 9
| Links | A link or HTML file from another app (Discord, mail, the terminal, xdg-open) opens as a new tab in the Glide you have (the window you used last), and you go to its tag; Glide stays where it is. No Glide open: a new window on the tag to your left if it's empty, else the nearest empty tag to the right, else the tag you're on. From Glide itself, a new tab. FreeTube windows (f on a YouTube link) are placed the same way
| Floating windows | The fixed ones above appear and disappear without sliding
| How | Plain mango (updated by update like everything else): the scripts move the window with mmsg (mm bring), and mm attention, started at login, brings windows that ask for attention (focus_on_activate=0 in the mango config, so they're only marked urgent)

## Top bar

> Left: workspaces and the window title. Right: system status. Colours follow the wallpaper.

| Workspaces 1–9 | Click to switch
| Window title | [layout] and the title of that monitor's window (or its app name), cut to 24 letters
| CPU: n% | Hover: the CPU's model, cores and threads. Click: CPU dashboard (model, speeds, temperature, per-core bars, busiest programs; q closes)
| Mem | Memory used (GiB). Hover: used / total. Click: btop
| Disk | Free space on /. Hover: used out of total (%). Click: ncdu (find what's using space)
| Volume | Left-click wiremix · middle-click mute · scroll 1% a step (up to 150%) · hover: the output device. Muted: dimmed, reads Muted
| Network | Wi-Fi name (long ones cut, the full name on hover), Wired, Disconnected or ⚠ Disabled (Wi-Fi switched off). Click: the wifi menu
| Battery | Only on a machine with a battery: its charge, green while charging or plugged in, orange at 30% or less, red and blinking at 20% or less. Hover: time left (or until full; plugged in, also how long the charge would last on battery, once it has run on battery). At 15% and not charging you get one warning
| Date | Click: calendar
| Time | Click: power menu
| Pomodoro icon | Shown while a session runs, dimmed while it's paused (Alt+p starts and pauses it; reset hides it). Left-click pause / carry on · right-click skip phase · middle-click reset · hover: time left
| VPN padlock | Shown while a VPN is up. Left-click: where you appear, your IP, the server, how long it's been up and whether the kill switch is on · right-click: leak test (route, IP, IPv6, DNS); hover: VPN active. Warns if the VPN drops
| Tray | Icons of running apps. Click: open it · right-click: its menu · middle-click: its second action · hover: its tooltip

## Quickshell panels

> Panels open with the keys in the Desktop section. Opening one closes any other (the calendar left on another tag too). Esc closes it (the screenshot tool steps back a stage first), as you let go of the key, so the window underneath never gets the Esc too (a fullscreen video stays fullscreen).

### Search lists (apps, emoji, time zones, wifi)

| Type | Fuzzy search: the letters in order, not necessarily together; matches are highlighted
| Esc | Once: leave the search box and use the list with single keys (Esc there clears the search). On an empty search: close
| Enter / click | Use the selected row
| Up/Down, Ctrl+j/k (typing), j/k (list mode) | Move
| Ctrl+s, or Space in list mode, or click ☆ | Favourite, pinned to the top (apps, emoji, time zones, wifi)
| / f i a (list mode) | Back to the search box

### App launcher (Super+d)

| List | Every installed app: favourites first, then the ones you use most and most recently; while you type, the best matches first
| Hidden apps | Not shown (see apphide in Tools)

### Emoji (Super+`)

| Search | By description; Enter copies the emoji to the clipboard

### Calculator (Super+')

| Where | A panel down the left side of the screen, the same height as the windows (the bar stays clear); the windows move over to make room beside it, so nothing hides behind it. Over a full-screen window it goes on top, the full height of the screen and covering that window's edge; when the window leaves full screen it goes back to its usual size. The box, the answer large with how many numbers it adds up, and recent sums filling the rest. It opens straight there, with the keyboard in it
| Typing elsewhere | It stays open while you type in a window: Super+h / Super+l away from the calculator's side (Super+l when it's on the left), or click a window (that first click hands the keyboard over; click again to put the cursor where you want). Back to it: click it, Super+h / Super+l towards it, or Super+j / Super+k (below). Super+' closes it; so does Esc while it has the keyboard (while a window has it, Esc goes to the window). With it closed, Super+h / Super+l resize as usual
| Alone on the tag | With no window on the tag it always has the keyboard (closing the last window, or going to an empty tag, gives it back)
| Which has the keyboard | The calculator: it has a coloured frame. A window: the calculator is dimmed
| Super+j / Super+k | The calculator is one of the windows they step through, from anywhere: Super+j from the last window, or Super+k from the first, goes to it; from it, Super+j goes to the first window and Super+k to the last. With one window they switch between it and the calculator
| Window keys | While it has the keyboard it moves like a window: Super+Shift+h / Super+Shift+l put it on the left / right, Super+space swaps its side; Super+Shift+j / k go to the windows and move them. While a window has the keyboard, these work on the windows as always
| Shift+h or Shift+f / Shift+l or Shift+j | With the box empty: move it to the left / right side; it stays there until a restart, then it's back on the left (in a sum they're capital letters, as in JPY)
| Sums | Live answer as you type: + - * / (or x) ^ ( ) sqrt(), 5% = 0.05, and a percentage added or taken off is a share of what comes before it (200+10% = 220, 200-10% = 180); commas added for you; spaces never needed. A list of numbers added up shows "5 items" ("…, 2 multiplied" for ones like 80x2)
| Money in a sum | 10%x$500 = $50, £12.50x3+£4 = £41.50: worked out as numbers, the answer with the symbol. Two different symbols ($5+£3) ask you to say which to show it in ('… to £')
| Enter or Tab | The answer replaces the sum in the box (the sum is kept under recents), to carry on from it (e.g. then +50)
| Shift+Enter · Esc | Done, with the answer copied (a note says what) and the sum kept under recents · close
| Ctrl+← → · Ctrl+Backspace / Delete | Jump by word · delete a word: an amount with its commas, point and symbol ($32,000) counts as one word, so it goes to its start or end, not the comma (Shift with the arrows selects)
| Ctrl+s (add up a selection) | Highlight lines (in nvim with V or the mouse; in the terminal with Shift+drag; or in the browser), open the calculator, Ctrl+s: every price is pulled into the box as a sum you can still edit. Per line it takes the number after £ $ € ¥ ₹ (lines without a price are skipped then, so "X13" or "34 Inch" never count), else the last number on its own; "x2" or "2x" multiplies it. The answer shows the £
| ans | The last answer: 'ans/12', 'ans*1.2', 'ans gbp to usd'. Under the answer it says what ans is while you use it
| Up / Down · click · Ctrl+d | Reuse past sums (50 kept, all in the list): click one, or step through them with Up/Down · clear that history
| Units | '5 km to mi', '5 kg' (gives lb and st), '5 ft 3 in in cm', '1 st 4 lb in kg'; shows the formula
| Kinds of unit | Length, area, volume, mass, speed, time, data, energy, power, pressure, angle, frequency, temperature, fuel economy
| Currency | '50 usd to gbp' or '$50 to £', spaces optional ('50usdtogbp', '$50to£'; '10kmin miles' for units too). Symbols too: $ £ € ¥ ₹ A$ C$ NZ$ zł…; and names: '50 pounds to yen', '20 dollars in euros' (yen, dollars, euros, quid, rupees, yuan, won, francs, pesos…). Just the currency after it converts too: '£50 yen', or '£50 y' (y and pounds mean yen and £ only beside money; '5 y' is still years, '5 pounds' still lb). 31 currencies, and any other code the downloaded rates have. The answer shows its symbol; yen, won and a few others in whole numbers
| An amount on its own | '£50' (or '50 eur', '3x£12.50') shows it in yen underneath, with the rate; a dollar or yen amount shows pounds
| Exchange rates | Only downloaded when you ask: once the saved ones are over 12 hours old (or there are none), a currency sum shows Update rates bottom right with the day they're from; click it (or Ctrl+u). Until then, and offline, the last rates are used; your answer fills in once they arrive. They're asked for as a plain Firefox would, nothing that names the calculator
| Trying the old-rates button | `~/.config/quickshell/launcher/calc/fx stale` makes the saved rates look 13 hours old; open the calculator, type a currency sum (e.g. 50 usd to gbp) and Update rates shows, as it will every 12 hours

### Calendar (Super+c, or click the date)

| Left | The month: a dot marks busy days, a second dot journaled ones; today is ringed
| Right | Your to-do list (today's to-dos and that day's routines), with the agenda for the picked day and the next two weeks under it
| Upcoming | Upcoming events show top right while it's open
| Stays put | It stays on the tag you opened it on: go to another tag and it hides, come back and it's there as you left it
| h j k l / arrows | Move the day (in the agenda and to-do: j k move, h l change day)
| H L / [ ] / PgUp PgDn | Previous / next month
| t | Today
| Enter or a | Add an event on that day
| e / d / D | Edit / delete the highlighted event, no questions asked (repeating ones: d that day, D every repeat)
| c | Open your plan in Neovim (a floating window in the middle): appointments, to-dos and routines
| Right-click a day, or z / Ctrl+j | Your journal for that day (the picked one, for z or Ctrl+j) in Neovim (today or earlier): just write, no template. Kept in your vimwiki journal (~/sync/notes/vimwiki/journal), one file a day in a folder for its year. The Journal link on your notes index (or Space W i in Neovim) lists the years, and each year its days; days you've written on get a second dot
| Tab / Shift+Tab | Grid → to-do → agenda / back
| Enter or e / a or o / d (to-do) | Open your plan / a new to-do line to type on / delete the task (routines can't be deleted here)
| x (to-do) | Cross the task out, or back in; crossed-out ones drop to the bottom. A to-do stays crossed out until you delete it; a routine only for today (it's back fresh next week)
| Mouse | Scroll over the month: change month · double-click a day: add an event · double-click an event: edit it
| Esc | Close
| Adding an event | Tab / ↓ next field, ↑ back, ← → change repeat and reminder, Enter saves, Esc cancels
| Dates | today, tomorrow, fri, next fri, 19/06, 19 jun, +3, 2w
| Times | 14:30, 2pm, 930; end as 15:30, +1h or 90m; no start time = all day. An end hour on its own before the start is pm when that's after it (14:30 to 4 = 16:00); an end before the start is the next day, and says so
| Event reminders | A notification 10 min before (all-day events: 09:00 on the day), unless you pick another time
| Where it's kept | ~/sync/calendar/calendar.ics, so it follows you to other machines
| Other calendars | Put each calendar's iCal link in ~/.config/calendar/feeds, one per line: shown read-only in a second colour, refreshed every 30 min

### Your plan (Alt+a, or c in the calendar)

| Agenda | One row per appointment: 23/11/26: Dentist (23/11 works too). Gone once the day is over
| Routines | One row per day: Tuesday: CCT, N-Back
| To-do | One per line under To-do, or anywhere as TD: task, task (commas make several). They stay until you delete them (d in the calendar, or in the file). Put [x] after one to cross it out (POSNER [x]), the same as x in the calendar
| Where it's kept | ~/sync/calendar/routines.md (Alt+a again closes it; open but not focused: brings it to you)

### Reminders (Alt+r)

> For today only: under 24 hours away. Anything on another day goes under Agenda in your plan (Alt+a).

| How | Alt+r opens the reminders still to come, one per line, with a new line to type on: what, then when. :wq sets them (:q with nothing typed just closes). Alt+r again saves and closes it (not focused: brings it to you)
| Times | A clock time: walk 14:00, 14:00:30, 2pm, 2:30pm. Or how long from now: walk 30s, 5m, 1h, 1h30m (s seconds, m minutes, h hours), or written out: 30 sec, 5 min, 1 hr 30 min, in 10 mins. The time can go first too (5 min tea); a clock time can end in tomorrow (walk 9:00 tomorrow) if that's under 24 hours away
| On save | Each line becomes the clock time it goes off (walk 5 min → walk 14:35:12), so what you see is what's set
| Refused | A clock time that's already passed today, 24 hours or more, or a line with no time: the window stays open with why, and the line stays for you to fix (:q! drops it; the others are set)
| Change / cancel | Edit the line's time / delete the line, then save
| When it's due | A notification that stays until you close it: click it or Alt+BackSpace (that's it done)
| Snooze 5 min | Button on the notification: back in 5 minutes
| Snooze… | Button on the notification: opens the window with the reminder on a new line to type the new time after (closing without one brings the notification back)
| Restart / reboot | Kept in ~/.local/state/reminders.json: still to come ones carry on; ones due while it was off, or not closed, come up as soon as the bar starts
| Screen recording | Held back like other pop-ups, and shown when the recording ends

### Time zones (Super+F3)

| List | Every country (one row per region where a country has several zones: Canada · Vancouver, Australia · Perth), US states and big cities, and UTC; each with its current time
| Search | A country, city, region or zone name (Europe/London, "Pacific", UK); or an offset: +9, utc-5, gmt+5:30 shows every zone at that offset
| Enter | Sets the system time zone (through timedatectl, so open apps hear about it). No password: the very first time it asks once to put its small helper in place (/usr/local/lib/tz-root, copied from ~/.local/lib/tz-root and allowed by /etc/sudoers.d/timezone); it asks again only if that helper changes

### Wifi (Super+F5, or click the network in the bar)

> NetworkManager's networks and wired connections, fully opaque. Connected first, then starred, then saved, then by signal. On a machine without wifi it only shows wired ones.

| Rows | A signal fan whose fill shows the strength (green on the connected network), a green "connected" pill or a grey "saved", the signal in %, and a lock on secured networks, in lined-up columns
| Search bar icon | The connected network's signal fan; an outline when not connected, crossed out with wifi off

| Enter | Connect (a new network with a password asks for it: Enter connects, Ctrl+h shows what you typed); on the connected one: its details
| Tab | Details: security, signal, the saved password (v shows it, Ctrl+c copies it) and the address
| Ctrl+d | Disconnect
| Ctrl+f | Forget a saved network
| Ctrl+r | Scan again (it also rescans by itself every 15 seconds)
| Ctrl+w | Wifi on / off
| Space / Ctrl+s | Star a network: starred ones stay near the top

### Power menu (Super+BackSpace)

| L or 1 · R or 2 · S or 3 | Lock · reboot · shut down, straight away (no confirmation)
| Esc | Close

### Lock screen

| Locks | From the power menu or with Ctrl+Alt+l
| By itself | After 45 minutes without keyboard, mouse or touchpad; not while something keeps the screen awake (a playing video, a fullscreen app)
| Unlock | Type your password and Enter. Shows a clock and how long it's been locked
| On lock | Pauses media, mutes sound, wipes the clipboard, closes kp, locks KeePassXC
| On unlock | Unmutes and resumes what it paused

### Notifications

| Pop-ups | Top right, up to three at once, newest on top: small cards in the wallpaper's colours, the app name above a title line and up to two lines of text, each only as tall as its text needs (longer text ends in …; the notification center has all of it)
| How long | 1.5 s each, always, whatever the app asks for; a line along the bottom counts down. Everything also goes to the notification center
| Pointer on them | Pauses them where they are: none closes or moves, and new ones wait until the pointer leaves. Moving off, each carries on from where it was (a second at least)
| Left / middle / right click | Close one / open the notification center (closing that one) / close them all but the reminders
| +N more | Under them when there are more than three: opens the center and clears the pop-ups
| Urgency | Low: plain (no accent bar) · normal: the accent bar · critical (errors, the pomodoro's phase changes): an accent border. Every pop-up leaves on its timer and stays in the center, except reminders (Alt+r), which stay until closed or snoozed
| Repeats | The same message again within 10 s, while it's still showing, adds ×2, ×3 to that card instead of a new one
| Progress | Downloads, transcribe and the like update one card with a bar; kp's countdown matches the clipboard clearing
| Always shown | Pomodoro work blocks and fullscreen windows don't hold them back
| Screen recording | Pop-ups are held back (so they're not in the video) and counted for afterwards; the recorder's own notices go only to the notification center. While paused, pop-ups show as usual
| Quiet ones | Skip the pop-up and only go to the center (each kept; ones sharing a sync tag replace each other)
| Per-app rules | ~/.config/quickshell/notifications/rules.json: quiet (center only) for any app; saved changes apply straight away
| Notification center | Super+Shift+n. Each one shows when it came (the time today, else the day and time). Keeps the newest 200, also when the shell reloads (after unlocking, say)
| In the center | j / k (or arrows) move · d or Backspace deletes · Shift+d or Clear All clears all · Esc or Super+Shift+n again closes it

### Screenshot tool (Super+p)

| Opening it | Freezes the screen
| The dock | Each button's key is printed under it (and in its label when you point at it): p turn it sideways, 1–9 the tools, [ ] size, u / r undo / redo, ⇧w remove a watermark, a whole screen, d delay; o opens a tool's colours. The same dock is in swayimg's e (draw on a picture)
| Selecting | Drag a box (drag inside to move it, edges to resize), or h j k l to grow it (Shift shrinks, Alt moves the box)
| Enter | Copy the selection (no selection, or a click without dragging: the full screen). Closing with Super+p or Esc both start the next time fresh (tool, colour, delay)
| c | Copy and save the selection
| s | Save the selection (or the full screen)
| f | Copy the full screen
| a or Ctrl+f (or the corners button) | Select the whole screen, so you can draw over all of it and then copy / save as usual
| t | Read the text in the selection (OCR) and copy it
| 🪄 (dock) or Shift+w | Remove a watermark: saves the screenshot (or the selection) like s, then opens it in IOPaint; Save there replaces the file. On a picture opened with e in swayimg it works on that picture itself (if you've drawn on it, on the copy with the drawing)
| d (or the delay button) | Delay 0 → 3 → 5 s: the next capture key counts down, then takes the live screen
| g | Change the rope style
| Esc | Step back: countdown, colour picker, tool, selection, then exit

#### Drawing

| Dock | Pen, highlighter, box, circle, arrow, text, line and numbered badges
| w / x, or Ctrl+l / Ctrl+h | Next / previous tool
| 1–9 | Pick a tool: 1 move, 2 pen, 3 highlighter, 4 box, 5 circle, 6 arrow, 7 text, 8 line, 9 numbered badges
| [ ] | Size
| u or Ctrl+z / r or Ctrl+y | Undo / redo
| p | Dock sideways
| o, or right-click the tool in use | Colours (o again closes them)
| Move tool | Picks up a drawing: arrows move it (Ctrl: further), [ ] its thickness, Ctrl+= / Ctrl+- a label's size, Delete or Backspace removes it
| Saved to | ~/Pictures/Screenshots
| On a saved image | Press e in swayimg: the same dock and keys; s saves a copy next to it named name-drawn, Enter copies and saves, Esc closes without saving. The original is never changed

### Wallpaper selector (Super+Shift+s)

| What | Browse ~/wallpapers as thumbnails
| h j k l / Enter | Move / open a folder or set the wallpaper
| Backspace / Esc | Go back / go back or close
| r / b | Random wallpaper / random from the highlighted folder
| / (or f i a) · n N · gg G | Search (in the box: Tab / Shift+Tab next / previous, Enter opens, Esc clears) · next / previous · first / last
| m (or s) | Day / night (night uses each folder's night/ subfolder, or its day pictures when it has none; on automatically at night)
| c / Shift+d | Rename the file in yazi / delete it for good (no undo)
| t | Move the picture into this folder's night/ (made if it isn't there), or, in a night/ folder, back out to the folder above. A picture of the same name there is replaced
| Shift+c / Shift+l / Shift+b | Change the layout
| o (or click the folder path at the bottom) | Use a different wallpapers folder: yazi opens; go into the folder and press q (Q cancels)
| Then f / j | Use it until restart / always (or h/l and Enter, 1 / 2, or a click); Esc cancels
| What follows it | Random wallpapers (Super+b) and the night switch use it too
| Back to normal | Choose ~/wallpapers with Always. In a terminal, wallpaper dir shows the folder in use
| No folder, or no pictures | It says so, with a Choose folder button (Enter presses it)

## Clipboard and links

| Links | Copying a web link removes tracking junk automatically (utm, fbclid, gclid, YouTube 'si', Amazon ref and more); a copied picture is left alone
| Passwords | kp clears a copied password after 15 s
| Files | yazi's y copies files so other apps can paste them; Y copies a file's contents (image or text)

## Terminal and shell (kitty + zsh)

> zsh in the kitty terminal, with vim keys at the prompt.

### The prompt

| Vi mode | Esc for normal mode; a block cursor in normal, a line in insert
| Suggestions | Grey, from history (and completions)
| Folders | Typing a folder name goes into it; each change of folder shows a short file grid (hidden files left out)
| History | Shared between terminals; a command starting with a space, over 300 characters or over 3 lines isn't kept; repeats are kept once
| Brackets and quotes | ( [ { " ' and ` close themselves; Backspace on an empty pair removes both

### Keys at the prompt

| Ctrl+o | Open yazi; when you quit, the shell moves to where you were
| Ctrl+f | Find a file (fzf) and go to its folder
| Alt+c | Pick a folder (fzf) and go into it (with text selected, Alt+c copies it instead)
| Ctrl+r / Ctrl+t | Search history / insert a file (fzf)
| Ctrl+e | Edit the command in Neovim
| Ctrl+Space | Accept the grey suggestion
| Up / Down or Ctrl+k / Ctrl+j | Search history for what you've typed
| Ctrl+w / Ctrl+Backspace | Delete the next word / the previous word (in fzf lists' search, both delete the previous word); at prompts that ask you to type (ud's username, send's where-to, Python) the same as in zsh
| Tab | Complete; h j k l move in the list, case doesn't matter, part of a word is enough
| Shift+Enter | Same as Enter
| Shift+Enter | Same as Enter
| y / p / P (normal mode) | Copy / paste after / paste before, with the system clipboard
| ci" da( … | Vim text objects work in normal mode

### Handy commands

| cd (zoxide) | Learns your folders: 'cd proj' jumps to the best match; cdi picks from a list (z, zi and c do the same)
| y or l | yazi that leaves you where you quit
| ls | eza with icons, folders first
| rm | Permanent, verbose, handles folders; never asks (read-only files go too)
| cp / mv | Ask before replacing a file, and say what they did
| ex FILE | Extract any archive next to it; into a folder that's already there it merges (same-named files replaced, the rest kept), so the parts of a split download (takeout-001.zip, -002…) add up (zip, 7z and rar through libarchive, tar ones through tar; a lone .gz/.xz/.bz2/.zst file is unpacked next to itself; a password-protected .zip asks for its password)
| mkcd DIR / mkd DIR | Make a folder and go in / make it (with any missing ones above it)
| cm, u, ka, sdn | chmod +x / unzip / killall / shut down now
| a, mpvl, sy | ani-cli / mpv on a loop / syncthing
| vim, mount, pacman, reboot… | vim is nvim; mount, umount, pacman, su, shutdown, poweroff and reboot run through sudo
| se | Pick one of your scripts and edit it
| yt URL / yta URL [1:00-2:30] | Download video / audio only (optionally a time range) into the folder you're in, named after the title. yt cuts out everything SponsorBlock marks (sponsors, self-promotion, like/subscribe reminders, intros, outros, recaps, filler, non-music). yta keeps the YouTube link and the thumbnail (its cover) in the file and, for a whole song, cuts out the parts SponsorBlock marks as non-music
| ytt [URL] | A YouTube video's captions as tidy text, saved in the folder you're in (no URL: the link you copied; ytt -c also copies the text)
| cat | bat with line numbers and colours (with an option, like cat -A, the real cat)
| p / Ss / pd | Update system / search packages / remove a package
| g, ga, gcm, gp, gin, gb, gr | git shortcuts (gp force-pushes to origin main; gin / gb / gr: git init / branch main / add origin)
| gcl NAME… | Clones your GitHub repos into the folder you're in (./NAME), one after another, each replacing the folder if it's already there; ones that fail are listed at the end and the rest still clone. Tab completes your repo names for each one (not those already typed). Also user/repo or a full link; git clone options go after the names: gcl NAME --depth 1. Your GitHub username is the one you typed into ud (u in its list); with none saved yet, gcl asks it once
| rs | rsync with progress and resume
| sip / ipa | Public IP / local IP
| xo file | Open it in its default app and go to the window it opened in, on its tag (like o in yazi); the prompt comes straight back
| v, si, i, f | nvim, sioyek, swayimg, fastfetch (in a narrow window without the logo; nothing wraps)
| cfv / cfz / cfm | Edit nvim / zsh / mango config
| vpn / vp | VPN on or off (as Super+u) / start it in this terminal. vpn avoid: countries it never connects to

### Folder shortcuts

| How | Type the shortcut at the prompt: 'yazi' ones open yazi there, the rest just go there
| In yazi | g + the letter shown goes to the same place
| pp · g p | ~/Pictures (yazi)
| wp · g w | ~/wallpapers (yazi); W goes there without yazi
| S · g s | ~/sync (yazi)
| L · g L | ~/Library (yazi)
| d · g D | ~/sync/documents
| D | ~/Downloads (g d in yazi)
| vd · g v | ~/Videos
| gi · g i | ~/github
| n · g n | ~/sync/notes
| cf / sc / dt / cac | ~/.config / ~/.local/bin / ~/.local/share / ~/.cache
| mh · g m / m | /mnt/hdd / /mnt
| rv | ~/RiseupVPN-OpenVPN

### kitty terminal keys

> kitty, the terminal: the wallpaper's colours, see-through, icons from Hack Nerd Font, Terminess (the Terminus letters). Pictures in notes are part of the text.

| Alt+c / Alt+v | Copy / paste (selecting text alone doesn't copy: it's only for middle-click paste); with nothing selected, Alt+c goes to the program (the shell's folder picker); in Neovim, Alt+v is Neovim's own paste (pictures too)
| Alt+k j / Alt+u d | Scroll a line / half a page
| Alt+Shift+k / Alt+Shift+j | Bigger / smaller text
| Alt+o / Alt+Shift+o | Open / copy a link on screen
| Ctrl+Shift+z / Ctrl+Shift+x | Jump to previous / next prompt
| Alt+Shift+c | Copy the last command's output
| Alt+Return | New terminal in the same folder
| Ctrl+Shift+n / Ctrl+Shift+o / Ctrl+keypad + − | Same as Alt+Return / Alt+o / Alt+Shift+k j

## Files: yazi

> Three columns: parent, current, preview. Vim keys (h j k l), plus these:

| l / Enter | Go into a folder or open a file (opens all selected files). A book (PDF, EPUB …) opens in sioyek on the tag you're on and yazi's window closes (a shell it was started from too); Shift+O opens it with its note and audiobook, and Shift+O on an audiobook opens it with its note and book (see Book, audiobook and note together)
| o | Open the selected files (or the hovered one) with plain xdg-open: each in its default app, books too (yazi stays open). You're taken to the window it opened in, on its tag: a new window, or the app's own already open (an .html goes to the browser's tag)
| Shift+L | Open with…: pick which app opens the file
| y / d / p | Copy / cut / paste (into the hovered folder)
| D | Delete permanently, straight away (no confirm box, no bin)
| F | New file (end with / for a folder)
| A | Make a folder and go into it (like mkcd; a/b/c makes the whole path)
| r | Rename; with several selected (Space, or v to sweep), all their names open in Neovim to rename at once (:%s/.txt/.md/ then :wq renames straight away, no question; :q! renames nothing)
| a | Invert selection
| Esc | Unselect everything, wherever you are: selected files and the y / d marks too (an open find, filter or search closes one per Esc)
| f | Filter as you type (Enter or Esc keeps only the matches; Esc again shows everything)
| i + letter | Jump to the next name starting with it (n/N repeat); the matching letters show as light blocks
| 5j, 12G, 3h, 2gt | Vim counts work: 3h goes up three folders, 2gt goes to tab 2
| g + key | Go to: g top, h home, c ~/.config, d Downloads, Space type a path, f follow a link; p Pictures, w wallpapers, s ~/sync, L Library, D documents, v Videos, i github, n notes, m /mnt/hdd
| m + letter / ' + letter | Save a mark / jump to it (kept after restart); m - clears them all
| s s / s g | Search names / search inside files (quitting in the results leaves the shell in the folder you searched)
| s c / c f | Go to ~/.local / ~/.config
| t / [ ] | New tab / previous, next tab
| z / Z | Jump to a folder you've been in (zoxide) / find one with fzf
| Ctrl+s | Show hidden files (in folder previews too)
| w / W | Shell here / running jobs (copies, moves, deletes; empty when nothing runs)
| e | Run the hovered script (result as a notification)
| u | Size of the hovered or selected items
| M | Mount / unmount drives
| b | Set the hovered image as wallpaper; on a folder, a random image from it (subfolders too)
| x | Scrub hidden data from files (photos also lose the camera's fingerprint)
| S | Send the selected files to another computer over SSH: asks where (send)
| Ctrl+g | Get files from another computer into the folder you're in: pick them from a list (send get)
| U | Publish the selected folders in ~/github (or the hovered one) to GitHub with ud; what happened stays on screen until Enter
| Y / c F | Copy file contents / copy file name (to give another file the same name: c F on it, then r on the other and Alt+v pastes)
| c m | Change permissions
| c s | Make audiobooks of the selected books (or the hovered one): see Audiobooks
| c t | Transcribe audiobooks, audio or video to Word and PDF: see Audiobooks
| c a a / c a p | Make an archive / one with a password (.zip unless you type .7z or .tar.gz; a password only on .zip, AES-256: it opens in 7-Zip, WinRAR, Keka or bsdtar, not Windows' or macOS's built-in unzip)

### Opening and previews

| Images, documents | Open as an ordinary tiled window next to yazi (books: see l / Enter)
| Text / video / audio | Neovim / mpv / the small audio player. Text files and notes open in nvim in yazi's own window; quitting nvim takes you back to yazi
| Archives · .kdbx · the rest | Extract here with ex (asks for a password if it needs one) · kp on that database (KeePassXC is next in the open-with menu) · the default app
| Previews | Rendered markdown, notes with their pictures in place (notes with no extension too; every picture shows at once, as part of the text: they scroll with it with J / K, and one at the top or bottom edge shows the part that's on screen), folder trees, what's inside archives, unit and .desktop files in colour, audio's cover (in ~/Audiobooks the one Books shows, elsewhere the one inside the file; its details if it has none), hex for binaries, git status
| Pasted copies | A copy named 'name_1' takes the original name back once the original is deleted

### yazi as the file picker for other apps

| Used by | Browsers, Vesktop, LibreOffice, Dangerzone and other apps open yazi to pick and save files
| LibreOffice | Type the extension (.docx) when you name a new file
| Opening a file | Enter picks · q cancels
| Saving | Starts in the app's folder (Downloads if it has none) with the file ready; walk to a folder and q saves there · R saves straight into the folder you last saved to · r renames · D or Q cancels
| Choosing a folder | Go into it and press q · Q cancels

## Writing: Neovim

> Leader is Space. Set up for writing, with notes, pictures and a readability checker.

### Set up for writing

| Spelling | US English spellcheck (UK spellings like colour are marked)
| Layout | Soft wrap, writing kept about 80 columns wide in the middle, relative numbers; a long line at the bottom shows as much as fits (no @@@)
| Clipboard and undo | System clipboard, persistent undo
| Status line | Word count and reading time
| Private files | No undo file for files in private/, /tmp, /dev/shm or /run/user, and once one is open that Neovim keeps no history (searches, commands, yanks, marks); what came before is kept
| Start | Plain nvim opens a start page: e new file, f find a file, g search inside files, r recent files, n notes, c config, q quit. No key hints pop up (Space ? lists the Space keys)
| No swap files | No "Found a swap file" question, and opening a file never waits for Enter
| Closing the window | Super+q (or a book set closing) saves every changed file and quits; text with no file name is thrown away; a file that can't be written (read-only) is kept in ~/.local/state/nvim/rescued and a notification says so

### Keys

| Space y | Copy the file or selection as flowing text (unwraps lines, keeps lists, headings and table rows on their own lines, leaves pictures out)
| Space b | Look up the word (or selected words) in the browser: searches "define WORD" with your default search engine and takes you to the browser
| Space H | Hemingway mode on/off (see below)
| Space G | Centred or on the left. Centred is Goyo (notes open in it) or, for other writing, the text kept about 80 columns wide in the middle. Space G takes this Neovim to the left: Goyo off, no side margins, and notes stop opening in Goyo; again: Goyo back on. In Goyo the status line with the word count stays; Space h hides it completely and brings it back
| Space o / Space h | Spellcheck on/off / hide the status line
| Space N | Line numbers off / on, in this window
| p / P, Ctrl+v or Alt+v (insert) | With a picture (or a copied image file) on the clipboard: paste it below / above; it shows in place. Alt+v pastes the clipboard anywhere, : lines too
| Space v / Space W … | Notes wiki index / other wiki commands
| S | Rename every match of the word (or selection) under the cursor: the :%s line comes ready to edit
| s / gs | Jump anywhere on screen by label / select a code block by label (flash); Ctrl+s while searching with / shows labels too
| ds / cs / ys (gS on a selection) | Delete / change / add surrounding quotes or brackets
| c | Change text without overwriting the clipboard
| Ctrl+Backspace (insert, : line) | Delete the previous word
| Space f / Space s | Format the file or selection (shell, JS, TypeScript, CSS, HTML, JSON, YAML, QML; others through their language server, like Lua) / shellcheck a script into a list below; both say when nothing applies
| Space j / Space k | Blank line below / above
| Space w / Space z / Space x | Terminal split / zoom window / open file with default app (saved first; a file with no name says Save it first)
| Space c | Copy the whole file
| Space d / Space D | Make this file a Word document in your house style / and a PDF (doc), next to it
| Ctrl+h j k l | Move between windows (skips the blank margins)
| Space B / Space O | Link a note to its book and audiobook / open them (see Book, audiobook and note together)
| Q / ZA / :w!! | Reflow text / save / save a root-owned file
| ZZ / ZQ / :q (note in Goyo) | Save and quit / quit without saving / quit; with unsaved changes :q says "No write since last change" and stays (no question asked), and so does :qa; :SaveQuit (or Super+q) saves every changed file and quits
| Space ? | List the Space keys
| :Hemingway, :PasteImage [name] | Hemingway mode for this file / paste the clipboard picture (as p)
| :PackUpdate | Update plugins (update does this for you)

### Automatic

| On save | Blank end lines removed, and trailing spaces too (not in notes and markdown, where two spaces end a line); JS, CSS, HTML and QML auto-formatted
| Word suggestions | Only words already in the file you're writing in (no snippets, no code or path suggestions). They pop up once you start a word (never after a space or a new line) in a solid box with a border, darker than the writing and in the wallpaper's colours, the chosen one on a clear bar
| In the suggestions | The little list of words that pops up as you type (from the file you're in): Tab / Shift+Tab, Ctrl+j / Ctrl+k or Ctrl+n / Ctrl+p move, Enter or Ctrl+y takes one, Ctrl+e closes it, Ctrl+Space opens it
| Language servers | Install themselves
| Margins and code | Git changes marked in the margin, indent guides, matching brackets in colour, colour codes shown in their colour, brackets and quotes closing themselves, HTML abbreviations (emmet)
| Moving in wrapped text | j / k move by screen line (with a count, by real lines); n / N keep the match in the middle; . on a selection repeats the last change on every line

### Pictures in notes

| p | With an image copied (from anywhere, including a browser, or an image file in yazi): it shows in place, its link hidden
| Calm | Pictures are drawn once you stop moving (about 0.3 s), no wider than the writing; they hide while you type or scroll (their space stays) and come back when you stop
| In kitty | Pictures are part of the text (the terminal is kitty): they scroll with it, never flicker or vanish, and nothing waits for you to stop. The calm drawing above is the fallback for other terminals
| On its line | The link stays hidden (dd still removes the line, picture and all); in insert mode it shows dimmed so you can change it
| Copying out | y, Space c and Space y leave the picture links out, so other apps get just the writing; pasting back into Neovim brings the pictures too
| Saving | Nothing is written until you save: on :w the picture goes into the wiki's images folder (~/sync/notes/vimwiki/images), notes outside the wiki too (like ~/ideas), so no images folder appears next to them. Pictures you paste but never save are deleted when you close
| Where they show | Markdown and vimwiki notes. A note with no extension in your home folder (like ~/ideas) opens as markdown, and pasting a picture into a plain-text note turns it into markdown
| Link form | A bare path on its own line isn't a picture: it needs the link form p makes, ![](images/name.png)

### Hemingway mode (Space H)

| Yellow / red | Hard / very hard sentences
| Blue / green / purple | Adverbs / passive voice / words with a simpler choice
| Top line | The grade level and the counts, with targets (empty until there's a sentence; a heading counts as its own paragraph)
| Click a purple word | (or the cursor on it and Space A) Shows the simpler words; pick one and it swaps in
| Space H again | Turns it all off

## Reading: sioyek PDF reader

> PDFs open here. Colours follow the wallpaper. Super+q closes it (q does nothing). Selecting text copies it.

### Moving and viewing

| j / k, Space / Shift+Space | Scroll / a screen down or up
| p | Go to a page
| K / J | Zoom in / out
| S / w | Fit to width / smart fit
| / | Search
| o / O | Open a book with yazi (starts in ~/Library, or home if there's no Library folder) / previous book (Ctrl+j / Ctrl+k move through that list, and every other sioyek list)
| i | Wallpaper colours on/off (F8 does nothing)
| Ctrl+d / Alt+f / Ctrl+n | Two pages / fullscreen / status bar
| f / Ctrl+f / Ctrl+b | Open a link / jump by label / go to definition
| F / Alt+c | Keyboard overview / copy
| Ctrl+t / Ctrl+Shift+t | Back / forward
| Ctrl+r | Reload the file from disk (after it was rebuilt or changed), staying on the same page
| H gh dh · b gb db · m gm · P gp dp | Highlights · bookmarks · marks · portals (add / go / delete)
| ; (with a word selected) | Look up its meaning: searches "define …" with DuckDuckGo in a new Glide tab and takes you there
| h / l | Scroll left / right
| V | Reading line: j / k move it down / up a line
| : | sioyek's command line
| Enter (with text selected) | Add the text to your notes: the book's note (as bookset links them), else the note open in Neovim (a wiki page, or any markdown file such as ~/ideas), or the book's own page
| Y | Drag a box round a figure: saved as an image into your notes with the page number (the same note Enter would use)
| c s | Make an audiobook of this PDF, in the background (like c s in yazi): follow it in Books (Alt+b)

### Book, audiobook and note together

| What | A book (sioyek) can open with its wiki note and its audiobook (Books), each on a tag of its own side by side; Super+; / Super+g step between them. Only when you ask for it: opened any other way, each opens on its own
| Which tags | The book on the tag you're on when it and the next one or two (one per thing opened) are free, else the first empty tags in a row, else the first empty tags anywhere; the note on the next tag, the Books player on the one after
| No note yet | Picking the note for a book that has none makes one: named after the book ("--Atomic Habits Original--", the page sioyek's Enter adds your highlights to) and listed in the wiki's index
| Linked by name | Same title, whatever else the names say: "Atomic Habits Original.pdf", "Atomic Habits by James Clear Full Audiobook.m4a" and the note "Atomic Habits" go together. Two that match equally well: neither is taken
| What's ignored | "original", "full", "audiobook", "unabridged", brackets, and the author in front of an audiobook's name ("Yuval Noah Harari - Sapiens.opus" goes with "Sapiens.pdf"). "by …" is left out after a dash or comma, or after two words of title, so "Bird by Bird" stays whole. Underscores count as spaces
| Linked by hand · Alt+l (sioyek, Books list) · Space B (nvim) | Pick the other two in a small window: each list has the one matched by name marked, "(none)" to have none, and for the note "+ a new note" named after the book (made and listed in the wiki's index). Esc on a list keeps what it had
| Shift+O (yazi) · Shift+O (sioyek's o picker) · Alt+Shift+s (the book in ~/Library sioyek opened last) | Asks what to open with the book: its note and its audiobook / its note / its audiobook (j/k move, Enter picks; q or Esc: nothing). Alt+Shift+s again while it's asking closes the question
| No audiobook, or no note | With no audiobook it just opens the book and its note; with no note yet it asks first (a note is only made when you pick it)
| Shift+O on an audiobook | In yazi (a file, a folder of parts in ~/Audiobooks, or a part in one): the same question the other way round, its note and its book / its note / its book
| Just the book | l / Enter in yazi, Enter in the o picker, Super+s. From yazi, yazi's window closes (a shell it was started from too) and its tag counts as free; from the o picker, that sioyek window is the book
| Then | The audiobook is ready where you stopped, paused. A set that's open already: you're taken to its tag
| Space O (nvim, on a wiki note) | Asks what to open with the note: its book and audiobook / its book / its audiobook (only the ones it has; Esc: nothing; nothing linked: a note says so, Space B links them). That nvim stays the note and the others open on tags beside it. Opening nvim any other way opens just the note, as always
| Closing | Close any of them and a small window asks about the rest (only the ones you opened with it that are still open): close them all too, just one of them, or keep them open (Esc keeps them). Close some yourself while it's asking and it asks again about what's left, or goes away when nothing is. Opening the same book again replaces the set it was in. Whatever you keep is asked about again when the next one closes. A closed audiobook stops with its place kept
| Where | Books in ~/Library, audiobooks in ~/Audiobooks, notes anywhere in the wiki (any folder, found by name wherever they are and whichever page links to them); links made by hand in ~/.local/state/bookset

## Audiobooks: Books and speak

> Books (Alt+b) plays your audiobooks and makes new ones: speak turns books and writing into audiobooks read by a natural voice. Making them all runs on this computer: nothing is uploaded, and it works offline.

### Books (Alt+b)

#### Your books

| Layout | ~/Audiobooks as a table (author, title, the voice that reads it, how far you are and the time left, length), on the left the book's cover (only a book downloaded from YouTube has one: the video's thumbnail) and its details underneath
| A book | An audio file; a folder of audio files (Author/Book/01.mp3…) is one book in parts
| At the top | Resume (the book you listened to last, with its time left) and Make an audiobook, then a line, then your books. Books being made show above the line too, with how far along they are and the time left (it updates as you watch)
| Enter | Play a book from where you stopped (a finished one starts again)
| Ctrl+r | Start any book from the beginning
| Ctrl+Backspace | Delete the word before the cursor in the search box
| Ctrl+e | Rename it: title, author (both saved into the file) and the file or folder name. Where you were, its bookmarks and its skips go with it
| Alt+l | Link it to its book and note (bookset); on Resume, the book it resumes
| Ctrl+d | Delete the book (or its folder of parts, and its cover next to it) for good, no bin and no question; where you were in it, its bookmarks, skips and speed go too (made again, it starts from the beginning). If it's playing, it stops
| Alt+s / Alt+x or Ctrl+d | On a book being made: pause or carry on making (all of them) / stop making that one
| Ctrl+y | Search YouTube for what you typed (audiobooks, unless your words say podcast, lecture or audio): the results take the list's place, with each one's thumbnail on the left. Esc goes back to your books
| Enter on words that match none of your books | The same YouTube search
| Nothing found | In the UK YouTube shows nobody signed in nothing at all for some words (sex …), so with the VPN off the list says to try again with it on (Super+u)
| Paste a link, Enter | Get that video (or one of the results)
| Getting one | It's downloaded into ~/Audiobooks with its chapters and thumbnail, then plays like any of your books. q while it downloads goes back to the list, where it shows as Downloading (with its %); it carries on, and a notification says when it's there. Ctrl+d on it stops it
| From a terminal | books LINK does the same
| Esc | Back to the player (with nothing playing: closes Books; from YouTube's results: back to your books)

#### The player

| Along the top | The book, its author and voice, and the whole book's time and %
| Left / right | The cover (a YouTube download's thumbnail; other books have none) / the chapters (when each starts and how long it is, the one playing highlighted) and your bookmarks
| Along the bottom | The chapter's progress (click to jump)
| Your place | Saved every few seconds, so closing it, or the computer turning off, loses nothing
| Speed | Each book keeps its own (a new book starts at normal speed)
| Covers | Only a book downloaded from YouTube has one: the video's thumbnail, saved inside the file when it's downloaded (so it stays when the book is renamed or moved). Every other book shows no cover
| e | Rename the book (as Ctrl+e in the list); it carries on from where it was (paused, it stays paused)
| Window | Keeps its size. Alt+b toggles it: on Books it hides it (what's playing carries on), hidden or on another tag it comes to you; never a second one

#### Keys

| Space / ← → / h l / j k | Pause / back, on 10 s / 30 s / 5 minutes (as set with T)
| T | How far ← →, h l and j k skip: press the key, type the seconds (or 5m), Enter. Remembered; ? shows them
| Super+Shift+m or Play key | Pause or carry on from anywhere, like every other player (pause all)
| n / N, J / K | Next / previous chapter (N or K within a chapter goes back to its start)
| [ ] / { } / Backspace | Slower / faster by 5% / 25% / normal (0.5× to 3×); the voice keeps its pitch
| b | Bookmark this spot (named after its chapter)
| 1 … 9 | Go to bookmark 1 … 9
| B | All bookmarks: j k move, Enter goes to one, d deletes it, q or Esc closes
| t … t | Skip a part from now on: t where it starts, t where it ends (either order). Until the second t the book never goes on to the next part: it waits, paused, at the end, so a skip can run to the very end. Esc (or t again on the same spot) forgets the first t
| S | All skips (start – end, length): j k move, Enter goes to one's start, d deletes it, q or Esc closes
| Skips | Playing into one jumps to its end (one that runs to the end of the book ends it); seeking into one yourself plays it. Kept with the book, so renaming keeps them
| ↑ ↓ or Ctrl+j Ctrl+k, PgUp PgDn, g G, Enter (or a click, or the wheel) | Go to a chapter
| - / = / m | Volume down / up / mute
| ? / q or Esc | All keys / back to your books (it keeps playing). Super+q closes it

### Making one

| In Books | Make an audiobook: pick the book (epub, pdf or docx from your folders, or paste the path of any file speak reads), then the voice (Tab plays a sample of it: a few seconds the first time, straight away after that). It's made in the background and shows in the list as it goes
| c s in yazi | Select one or more books (or hover one) and press c s: they're made the same way, in the background; follow them in Books. Press c s on more books while it works and they join the end of the list
| c s in sioyek | The PDF you're reading, the same way
| speak FILE… | The same from a terminal, in that terminal
| speak -w | The speak window: carry on with whatever is still waiting, and change voices, speed and order (only when nothing is being made in the background; otherwise follow it in Books)
| Reads | pdf (including scanned and photographed pages), epub, docx, txt, md, html, srt/vtt subtitles
| Saved as | ~/Audiobooks/Author - Title.opus (the author and title from the book itself), with a chapter mark for each chapter, the voice that read it, and the book's cover next to it (from the epub, or a PDF's first page). Small files: about 18 MB per hour
| When it's done | A notification says it's ready and how long it is (or why it couldn't be made); it's in Books straight away

### What happens to a book

| 1. Text out | The text is taken from the file. For a PDF, any page that's only a picture of text (scanned or photographed) is read with OCR (tesseract) instead; that reading is kept, so it's only done once
| 2. Tidied | Left out: running headers and footers (the book or chapter title repeated on every page), page numbers (12, xii), footnote numbers, web links and markdown symbols. Words split by a hyphen at the end of a line are joined again. Tables (in a PDF, epub, docx, web page or markdown) are read row by row
| 3. Chapters | From the epub's chapters, the PDF's table of contents (its bookmarks), or Heading 1 in a docx. Plain text is one chapter
| 4. Said right | Abbreviations, numbers and symbols become words: e.g. → for example, Dr. → Doctor, St. Mary St. → Saint Mary Street, Chapter IV → Chapter 4, Henry VIII → Henry the Eighth, 1990s, £5, 5 km, 3:30pm, 1914–1918
| Keys and paths | Read the way you'd say them: ? is 'question mark', o / O is 'o or capital O', ~/sync/documents is 'sync slash documents', times.conf is 'times dot conf', -u is 'dash u', PgUp is 'Page Up'
| Pronunciation | Your own pronunciations go in (see Voices). Then misaki, the pronouncer the voices were trained with, works out the sounds from the whole sentence, so read, wound, wind and live are said the right way for their meaning
| Spelled-alike words | Where misaki guesses wrong, the words around fix it: lead the metal (lead-grey, lead pipes, heavy as lead), a bass guitar, taking a bow, minute details, a blazing row
| 5. Spoken | By the Kokoro voice a few sentences at a time, so the tone carries from one sentence to the next instead of each ending flat; a pause after them, longer ones between paragraphs and chapters
| Tables | A short pause between a row's cells (a key and what it does), a longer one before the next row, and longer again when the table ends
| 6. Saved in parts | About every four minutes of speech is saved as a part in ~/.cache/speak. Stop at any time (q, closing the window, shutting down) and the next run carries on from the last finished part
| 7. Joined | The parts become one .opus with the chapter marks, and the parts are deleted

### The speak window

| Each line | A book with its voice and speed
| Waiting / finished | Roughly how long its audio will be / a tick and its length
| Being made | A progress bar, which chapter it's on, how much audio is made so far and the time left
| All books | With several books, a bar with the time left for all of them, worked out from how fast this computer is going
| j / k (arrows), gg / G | Pick a book
| v / V | Next / previous voice for that book
| ] / [ | Faster / slower, in 0.1× steps (0.5× to 2×)
| Enter / Esc | After changing the voice or speed of the book being made: Enter starts it again with the change, Esc keeps going as it was. Books that haven't started just change
| J / K | Move the book down / up the list
| dd | Take the book off the list
| p or Space | Pause / carry on
| q | Stop. The list is kept: c s in yazi, Books or speak -w carries on
| ? | Show these keys

### Voices

| heart | Warm, natural woman (the default; the best of the voices)
| bella | Bright, lively woman (nearly as good)
| nicole | Soft, close, almost whispered
| sarah | Natural, even woman
| onyx | Deep, flat man
| Default voice | Put 'default onyx' (any name) in ~/.config/speak/voices
| Hear them all | speak --samples saves a short sample of every voice, one after another, as ~/Downloads/speak-voices.opus (or press Tab on a voice when making an audiobook in Books)
| Two voices in one text | A paragraph starting 'onyx: …' is read in that voice; handy for dialogue
| Words it says wrong | Add them to ~/.config/speak/words, one per line: 'Hermione = her-my-oh-nee' (hyphens join the parts into one word), or a phrase: 'lead pipe = led pipe', or exact sounds between slashes: 'Hermione = /hɜːmˈIəni/'. Used straight away, even by a book being made. Test with speak -c

### From a terminal

| speak -v onyx -s 1.2 FILE | Choose voice and speed
| speak --pages 12-340 FILE.pdf | Only those pages: skip the contents, index, notes…
| speak -p FILE | Play it while it's being made
| speak -o OUT.opus FILE | Save somewhere else
| speak -c / speak - | Read out what's on the clipboard now / what's piped in (nothing saved)
| speak -a FILE… | Make them in the background (like c s), followed in Books
| speak -l | List the voices

#### Good to know

| First use | Installs the voice engine (about 400 MB, once), where you can watch it
| How long | A long book takes a while; it depends on the computer, and the window shows the time left. Keep working meanwhile
| Other languages | Scanned books in another language: set SPEAK_OCR_LANG (e.g. deu) and install that tesseract language

### The other way: audiobooks to Word and PDF (transcribe)

| c t in yazi | Select audiobooks, audio or video (or hover one) and press c t. Notifications show progress
| transcribe FILE… | The same from a terminal, with progress and time left. Makes FILE.docx and FILE.pdf next to it
| -m tiny / base / small / medium | Model: smaller is faster, bigger makes fewer mistakes (default base)
| -l fr / de / auto | Not English: say the language (or auto)
| -k | Also keep the text as FILE.md

#### Good to know

| Offline | Runs on this computer (whisper). The first run of each model downloads it once
| Chapters | Become headings; title and author come from the file
| Stopping | Any time: the next run carries on from the last finished chapter
| How long | A whole book takes hours without a graphics card; tiny is quickest

## Web: Glide browser

> Firefox with vim keys. The mode is shown left of the tabs (nor, ins, vis, hint, cmd, op, ign). Press ? for the full key list.

### Pages and tabs

| j k h l / d u / gg G | Scroll / half page / top, bottom
| f / F | Click a link by label / open it in a new tab
| t / x / X | New tab / close tab / reopen closed tab
| J / K | Tab left / right
| Space 1–9 / g0 g$ | Go to tab N / first, last tab
| Ctrl+1–9 | Move this tab to position N
| H / L / r | Back / forward / reload
| o / O | Address bar / in a new tab (in it, Ctrl+j / Ctrl+k move down / up the suggestions)
| b / B | Search bookmarks / in a new tab
| T | Search open tabs
| p / P | Open the link (or search the text) on the clipboard / in a new tab
| s / gi | Focus the site's search box (none: the address bar) / a text box
| yy / yt | Copy the URL / duplicate the tab
| yi / yI / yd | Copy an image / its URL / download it
| Ctrl+f, n / N | Find, next / previous
| gm | Mute the tab
| Space m | Compact mode: hide tabs and address bar until you move to the top
| Space i | Turn Glide's keys off for this site, every time you visit it (remembered; subdomains too). To turn them back on for good: Esc Esc, then Space i
| Esc Esc (or Shift+Esc, or click the mode label) | Keys off / on for now
| Space n / Space q | New tab / close tab
| Ctrl+Left / Ctrl+Right | Previous / next tab
| Space s / Space R | Save the page / reload the config
| s d r z x v (on YouTube) | Go to the video speed controller instead

### Typing in text boxes

| Esc | In any text box: vim editing
| Edits | d and c with w e b $ 0 ^ G gg, dd, cc, D, C, S, x
| u / Ctrl+r | Undo / redo
| yy (Y) / p / o / v V | Copy the line / paste / new line / select (V: the line), then d c y x p
| Focus | Sites can't grab your typing focus by themselves

### Tabs, start page and search

| Tab bar | Works exactly as in Firefox (drag to reorder or out to a new window; tabs shrink as you open more), in your own look: the open tab is a rounded shape joined to the address bar, short dividers between the others, colours from the wallpaper, and the mode label on the left
| Ctrl+1–9 | Moves the tab to that position
| Size | Everything in Glide (tabs, bars and pages) is 15% bigger, since the screen itself isn't scaled
| New tabs | An empty page in the wallpaper's colours (new windows too); a new wallpaper shows on it within a second, no reload needed
| Start tabs | Space T (leader T) makes the open tabs your start tabs: Glide always starts with them, opened all at once as its first tabs (a link it was started with comes first and shows). Another window while Glide is open gets one new tab. Started again just after you closed it (it's still wiping its history), it waits for that to finish (up to 20 s), so it starts afresh with the start tabs. Edit or empty the list in ~/.config/glide/start-tabs (empty: Glide starts on a blank tab)
| Search engines | In the address bar, ddg / sp / 4get + space choose the engine
| Privacy settings | arkenfox, hardened: see Privacy and safety

## Video and audio

### FreeTube (Super+Shift+f)

| YouTube links | Clicking one anywhere (a web page, the terminal, Discord, mail…) asks: f FreeTube (a new window on the closest free tag), j YouTube in the browser (a new tab in Glide if it's open, and you're taken there; else a new window on the closest free tag); Esc opens nothing. On YouTube itself links work as normal
| Keys | FreeTube's own (the vim keys were removed: FreeTube updates could break them); its own colours, not the wallpaper's

### mpv

| h / l | Back / forward 20 s
| j / k | Back / forward 60 s
| o / p | Slower / faster (0.1× a press)
| - / = | Volume down / up (5% a press)
| Click | Pauses / plays (a double-click no longer goes fullscreen)
| The bar | Moving the mouse anywhere over the video shows the controls at the bottom; they hide again when it stops
| ~ / @ | Next / previous chapter
| c | Shows / hides the chapters as a panel on the right, in the playlist's place (one at a time: c while the playlist is up swaps to the chapters). Up again next time if you left it up. A video with no chapters says No chapters
| In the chapters | At the top the title and the chapter you're in (3 / 14). Each row: its number (▶ on the one playing), a frame from its start with its length, a bar for how far into it you are, and its name with its start time and length
| Chapters panel | Click a row to jump to that chapter; the wheel over it scrolls. While it's up: Ctrl+j / Ctrl+k (or ↓ ↑) move, gg / G first / last, Enter jumps there (on the chapter you're in: back to its start), Esc (or c) hides it. Those keys only change while it's up
| s | Subtitles on / off
| Shift+s | Screenshot of the video, subtitles included, into ~/Pictures/Screenshots
| a | Next audio language (never stops on no sound)
| z / x | Zoom in / out
| Online video | Up to 1080p with English subtitles. A video opened from a YouTube playlist (or the playlist's link) brings the whole playlist, starting at that video: Tab shows it
| Slow streams | When a stream runs dry mpv waits until it has 10 s more before carrying on, so it stops less often
| SponsorBlock | On YouTube videos (and downloads that weren't cut) the parts it marks are skipped: sponsors, self-promotion, like/subscribe reminders, intros, outros, recaps, filler, non-music. A note says what was skipped; seek back into one to watch it
| ani-cli | Japanese and English audio, starting in Japanese: a switches. Japanese always brings the subtitles back (even after s turned them off); the English dub hides them, since its script is different. The streaming site's logo burned into the top-right corner is blurred away, at any quality
| ani-cli openings | → l and k jump past an opening or ending while one plays (a note says so as it starts); elsewhere they seek as usual. Nothing is skipped by itself. Times come from ani-skip; episodes it doesn't know play as normal
| ani-cli resume | Reopening an episode carries on where you stopped, and ani-cli -c offers an unfinished episode again instead of the next one. Watched to the ending (or the last 1½ min), it's done
| ani-cli elsewhere | In a terminal, a is short for ani-cli. Downloads (ani-cli -d) go to ~/Videos/Anime
| q | Does nothing: Super+q closes it (a video file, or an ani-cli episode, carries on there next time)
| A folder of videos | Opening one plays the folder from it on, by name, one after another (like a playlist). A video you stop partway carries on there next time; ones watched to the end are remembered
| Tab | Shows / hides the playlist (the folder's videos, or a YouTube playlist) as a panel on the right, like YouTube's, the video moved over to make room. It stays up while you watch, and is up again next time if you left it up (c swaps it for the chapters)
| In the playlist | At the top the folder's name (a YouTube playlist's title and channel) and where you are (3 / 14). Each row: its number (▶ on the one playing), a frame with its length, a bar for how far you got, and its name with the channel (or Watched / time left)
| Playlist panel | Click a row to play it; the wheel over it scrolls. While it's up: Ctrl+j / Ctrl+k (or ↓ ↑) move, gg / G first / last, Enter plays, Esc (or Tab) hides it. Those keys only change while it's up
| Audio files | In ~/Audiobooks: open in Books (while it's open, the file plays in it and its window comes to you). Anywhere else: a small mpv window that plays the rest of the folder; closing it stops the sound

### Images: swayimg

| h l (or j k, or the arrows) | Previous / next image in the folder (in the gallery: move the selection)
| [ ] / g G | Previous / next folder / first, last image
| x z (or + −) / = / 0 | Zoom in, out / 100% / fit
| Shift+h j k l (or Shift+arrows) | Pan
| r R / m M | Rotate / flip
| f / i | Fullscreen / info (hidden at first, in the gallery too; i shows it)
| y / b | Copy the image / set as wallpaper
| c | Copy its full path
| s | Slideshow from here, a new picture every 4 s (h l step); s or Esc stops
| e | Draw on it with the screenshot tool's pens; s saves a copy named name-drawn
| w | Remove a watermark: opens the picture in IOPaint in a window of its own (not the browser; closing it stops IOPaint). Works fullscreen too: the window opens on top. The cleaned picture shows straight away
| In IOPaint | Brush over the mark, let it fill in, press Save and it replaces the picture. All on your computer, nothing uploaded; takes about 30 s to start
| Shift+d | Delete permanently
| Tab / Enter, Space or a click | Thumbnail gallery / open the picture (Ctrl+d Ctrl+u or Ctrl+f Ctrl+b: a page down / up in the gallery)
| q / Esc | The gallery: the folder you opened from and the folders inside it (on a picture in ~/wallpapers/anime, q shows anime's and night's), with the one you were on picked. Never anything above that folder. Neither closes it: Super+q does

## Privacy and safety (OPSEC)

> OPSEC means not giving away more than you mean to: who you are, where you are, what you use, what you have. Each layer below closes one gap. None is perfect alone; together they make you a much harder target than a default setup.

### kp: passwords in a terminal (Super+Shift+d)

| Opens | Your KeePassXC database (asks for the master password); opening a .kdbx in yazi opens kp on that one, without changing your usual one. Always fully solid (Super+- doesn't make it see-through); the row you're on is a solid bar, bold, with a ▶
| j k / l or Enter / h / / (or Ctrl+f) / g G / q or Esc | Move / open a folder or copy the password / up / search / top, bottom / close kp
| u | Copy the username
| a | Copy the login: the username now; once you paste it, the password is copied in its place. kp hides until you paste the password, then comes back (Super+Shift+d brings it back sooner); the password clears 15 s after it's copied; not pasted within a minute, the username clears and the password isn't copied. Ctrl+a in search, a in an entry's edit view
| e / n / p | Edit an entry / make a new one / the password generator (r new, h/l or - + shorter/longer, 1–4 character types, w words)
| Shift+D | Delete the entry you're on, straight away (also in its edit view; Ctrl+d in search). It's gone for good, not put in the Recycle Bin. Folders are deleted in KeePassXC
| In an entry (e) | Enter changes the line you're on (Notes opens in your editor; for Password, Enter on its own opens the generator) · s shows or hides the password · y copies it · u the username · a the login · Shift+D deletes it · h, q or Esc back. A field can't be emptied
| Ctrl+o | Open another database: lists every .kdbx in your home folder (j/k move, Enter or l opens, Esc or q stays; nothing to type); the one you pick becomes your usual one. Works at the master password prompt too, any time (Esc there closes kp)
| After copying | kp hides itself until you paste what it copied (Ctrl+v, Ctrl+Shift+v or Shift+Insert, anywhere), then comes back. Once the copy is cleared or you copy something else, pasting no longer brings it back. Super+Shift+d brings it back any time. Copied secrets clear after 15 s
| In search | Enter copies the password, Ctrl+u copies the username, Ctrl+a the login, Ctrl+e edits, Ctrl+d deletes
| A login | Copy the username, paste, copy the password, paste: kp gets out of the way and back by itself
| Super+Shift+d again | Hides it without locking it; once more brings it back
| Why it matters | One strong, different password per site means one leaked site can't open the others. The database is encrypted on disk, so a stolen laptop or backup gives nothing without the master password. Copies are marked 'sensitive' and wiped after 15 s, so they don't linger on the clipboard for another app (or a screen share) to see.
| KeePassXC | Locks itself after 5 minutes idle and when you lock the screen.

### send: files to and from another computer (S and Ctrl+G in yazi)

#### How it works

send copies files from this computer to another one (or from it to here) over SSH, the same secure connection you'd use to log in to it remotely. The copying itself is done by rsync, which only sends what isn't there yet and can pick up where it left off.

- **The other computer only needs its SSH server on.** If you can already ssh or rsync to it (your host can), there's nothing to do there. If not, send receive on it turns the SSH server on, lets SSH through its firewall, and prints the send setup line to type on the other computer (one per network: your Wi-Fi, a VM network…).
- **Once, on either computer (optional, but nicer):** send setup user@address gives that computer a short name (laptop, host…) and saves it in ~/.ssh/config. It also puts your SSH key there, so from then on nothing asks for its password (you type it this one time). That name then works everywhere: ssh laptop, rsync and send. It then sets up the other way too: it asks a name for this computer, saves it in that computer's ~/.ssh/config and lets its key in here, so both can send to each other after one setup.
- **Any number of computers:** run send setup once for each (host, laptop, pi…), then pick one by name when you send. You can also skip setup and type user@address:PATH straight in; that works too, but asks for its password every time.
- **Every time after that:** select files in yazi and press S (or send FILE… in a terminal). With more than one computer saved it first lists them (the one you used last on top: j/k move, Enter picks); then it asks where on it, with the path you last used there already filled in, so usually you just press Enter twice. The other computer shows a pop-up when they arrive; clicking it opens that folder.
- **Getting files instead:** in yazi, go to the folder they should land in and press Ctrl+G (or send get in a terminal there). It lists the files on the other computer; pick some and they're copied here.
- **Addresses that change:** routers hand out new addresses now and then. send receive makes a computer answer to a name on your network (like laptop.local), and setup saves that name instead of the address when the other side answers to it, so sending keeps working after a reboot.
- **Where to** is NAME:PATH, like laptop:~/Pictures/ or host:~/inbox/, or user@192.168.1.20:~/inbox/ for one you haven't named. Pick another computer from the list (or other… to type one), or change the name at the prompt; it remembers the last path for each computer. A path ending in / is a folder: it's made if it isn't there and the files go inside it.
- **If it stops halfway** (the other computer went to sleep, the Wi-Fi dropped), send the same files again. Finished files are skipped and a half-sent one carries on from where it got to.
- **Nothing is deleted or moved:** the files stay here too, and other files on the other computer are left alone. A file there with the same name as one you send is replaced by yours.

#### Reference

| Once, on the computer that receives | send receive: turns its SSH server on (and keeps it on: updates leave it alone from then on), turns on avahi so it answers to NAME.local on your network, lets both through the firewall, and prints the send setup line to use, one per network it's on (your Wi-Fi by name, each VM network)
| Once, on either computer | send setup user@address: asks a short name for that computer (laptop, say) and adds it to ~/.ssh/config, so the name works in ssh, rsync and send; puts your SSH key there (making you one first if you have none; its password, once), makes sure it has rsync, and fills the name in as where to send. Setting up a name again replaces its old address
| The other way | Setup then does the same from there: turns this computer's SSH server on, makes that computer an SSH key if it has none, lets it in here, asks a name for this computer and saves it in that computer's ~/.ssh/config (and as where it sends). It checks that computer can reach this one; if it can't (another network, behind a router), sending there still works and only the way back waits
| Already named | send setup NAME (one from ~/.ssh/config, like host) uses its saved address; send setup user@address NAME names it without asking
| Names, not addresses | At the end setup tries each computer's network name (NAME.local) and, if it answers with the same SSH key, saves that instead of the address, on both sides. A computer set up before this keeps its address: send receive on it, then send setup NAME again
| Its address changed | If the saved address can't be reached, setup says so and asks for the new one (user@address), then saves it under the same name. send receive on that computer shows its address
| If setup stops | "is there, but its SSH server is off": run send receive on it · "its firewall blocks SSH" (it answers ping, but not SSH): run send receive on it · "answered, but the key couldn't be put there": wrong user or password · a computer that doesn't answer at all gives up after 10 seconds
| Sending | S in yazi, or send FILE… in a terminal: with more than one computer saved, a list of them first (the last one used on top; j/k move, Enter picks, q cancels, other… types user@address); then where on it: the computer stays fixed at the start of the line and you edit only the path, filled in with the one last used there. With only one saved it goes straight to where. A folder goes over as the folder itself
| Where to | A path on that computer, like ~/Pictures/ or ~/inbox/. Ending in / it's a folder (made if missing) and the files go into it; without, one file is sent under that name (sending several, it's always a folder). The line works as in your terminal (zsh: vi keys, Ctrl+Backspace…), and Tab completes from the folders and files on that computer just as it does here: the list in your colours, Tab again for the menu, arrows or hjkl to move, Enter picks (only with its key set up, i.e. after send setup). Empty or Ctrl+C cancels. other… asks for user@address first (user@address:PATH fills in the path too)
| Progress | One line for the whole lot: how much is done, the speed and the time left
| Stopped halfway | Send again: it picks up where it left off and skips what's already there unchanged. A pop-up says when it's done or failed
| On the other computer | A pop-up "Received FILE from THIS-COMPUTER → FOLDER"; clicking it opens the folder in yazi. Nothing shows if nobody's logged in there
| Getting files | Ctrl+G in yazi, or send get [NAME] in a terminal: asks which computer (the same list as sending, or last one filled in when only one is saved), then lists its files and folders (not hidden ones; folders end in /). Type to search, Ctrl+J/K move, Tab ticks several (a green ✓), Enter copies them into the folder you're in. A folder comes over as the folder itself; files here with the same name are replaced
| Undo the setup | send forget shows one list with nothing ticked: named computers, other addresses this computer remembers from SSH (connecting there again asks once to trust it), computers allowed to log in here, and this computer's SSH server (with its network name, if send turned that on)
| In that list | Nothing to type: j/k move (▶ and a grey bar on your line), Enter on a line forgets that one and it's done. For several: Space ticks or unticks and goes to the next (green ✓), a ticks all (again: none), the top counts the ticked ones, Enter forgets the ticked ones. q cancels
| Then | A forgotten computer's address and its last path go with it. Your own SSH key stays (GitHub uses it)
| A setup that fails | Nothing is saved: a computer that couldn't be reached (firewall, SSH server off, wrong address or password) is taken out again, so it never shows up when you send. The same goes the other way: if the other computer can't reach this one, it isn't saved there

### Scrub: hidden data in files (x in yazi)

| Why | Photos, videos, PDFs and office files carry metadata you never see: where a photo was taken (GPS), the phone or camera model and its serial number, exact dates, your name and computer name, editing software, thumbnails (which can still show what you cropped out) and document history. Sharing one file can give away your home, your device and your identity. scrub removes it
| What it does | Rewrites each file in place with that hidden data removed: the picture, sound, text and layout stay exactly as they were. No copy of the original is kept, so it can't be undone
| Photos | jpg (also .jfif / .jpe), png, webp, tif, heic, avif, gif, jxl, and downloaded pictures with no extension or a wrong one (it looks at what's inside): everything hidden goes (GPS, camera and phone model, serial number, dates, editing software, your name, thumbnails); only the orientation and colour profile stay, so it still shows the right way up and in the right colours
| Video and audio | mp4, mov, mkv, webm, mp3, flac, ogg, opus, wav…: location, device, dates, encoder and the names and comments a phone or editor adds
| Documents | PDF, Word / Excel / PowerPoint (docx, xlsx, pptx), LibreOffice files, epub, svg, zip, tar, torrent: author and company, computer name, dates, editing time, revision history, comments, the software used
| Camera RAW files | Only the location, serial numbers and names (the rest is needed to develop the photo; Nikon's serial number stays)
| Can't be cleaned | Old .doc / .xls / .ppt (save them as .docx / .xlsx / .pptx first). bmp holds no hidden data
| Screenshots | Nothing to scrub: Super+p screenshots (saved or copied) hold no hidden data at all, not even the time they were taken. The clipboard itself can't be scrubbed: scrub works on files
| Downloads | Cleaned by themselves: each new file in ~/Downloads (not in folders inside it) has its hidden data removed once it has finished downloading (scrub without -p: downloads keep every pixel). A notification says what was cleaned
| Left as they came | Zips, tars and torrents, so they still match a checksum or signature published with them (x in yazi cleans one if you want); files already there when it was turned on (scrub-downloads --all cleans them too). Why a file wasn't cleaned: ~/.local/state/scrub-downloads/last-run.log
| x in yazi | scrub -p on the selected files (or the hovered one): the data above, plus the camera's fingerprint on photos that still have camera data (screenshots, downloaded pictures and photos already cleaned keep every pixel, so cleaning twice doesn't soften them); a notification says what was cleaned
| scrub FILES / folders | Strip the hidden data (photos, video, audio, PDF, office files, epub …). A folder is reported as one line with how many of its files were cleaned; files given one by one are each named. Hidden files and folders inside a folder are left alone
| scrub --check FILE | Show what a file gives away, without changing it
| -r | Also give random names (IMG_20261007_142233.jpg gives away the date and time)
| -p | Also hide which camera took a photo (below). x in yazi always does this

### Why -p: the camera's fingerprint

| The fingerprint | Every camera sensor has tiny, permanent manufacturing flaws: some pixels are always slightly brighter or darker than the rest. This pattern (PRNU, photo-response non-uniformity) is in every photo the camera takes and survives deleting the metadata
| The risk | Forensic tools compare a photo's noise with a known photo from your phone and can say "same camera", so two photos you post under different names can be linked
| What -p does | Crops a random 1–8 pixels off each edge (so every pixel moves), then scales the photo to a random 92–99% of its size with Lanczos (sharp), then saves it again at high quality
| Why it works | To match, the fingerprint has to line up pixel for pixel. Because the scale isn't a whole number, no new pixel sits on an old one: each is worked out (interpolated) from its neighbours, which smears the flaw pattern and leaves it out of step with the reference. You can't see the difference; the fingerprint test fails
| Stronger ways | Linear interpolation (a triangle filter) mixes neighbouring pixels in proportion to distance; Lanczos (what scrub uses) weighs a wider area. Stronger still is a slight non-linear warp (bending the image a little, more at the edges than the middle) shifts every pixel by a different amount, which a forensic tool can't undo with one simple shift and scale
| Why scrub keeps it simple | Crop + Lanczos scale is fast and keeps photos sharp. For something truly sensitive, also don't post photos from the same phone under both names

### Dangerzone: suspicious documents (dangerzone)

| What | Turns a PDF, office file or image into a plain, safe PDF inside a sandbox; pick files with yazi
| Why | Documents can carry malware or tracking (scripts, macros, hidden links that report when you open them). Dangerzone renders the pages to pixels in a locked-down container with no network, then rebuilds a clean PDF from those pixels, so nothing hidden survives
| Keys | j/k move, h/l, gg/G, Ctrl+d/u; s selects documents and converts them; 'Save safe PDFs to' is ticked for you
| Where | The safe copy is saved as NAME-safe.pdf in ~/sync/documents, with its text made searchable (OCR, English), and opens in sioyek

### VPN with a kill switch (Super+u, vp)

| Super+u | On or off: runs vp in a terminal on tag 9, and you stay on your tag. Off and straight back on: if the last one is still disconnecting, a notification says to try again in a moment. Off before it's connected says so too (VPN off)
| vp / vpn fetch | Start it in the terminal you're in / download the config again
| vpn avoid | The countries (or cities) it never connects to, one per line (~/.config/vpn/avoid): France and Netherlands at first, which leaves the US and Canada. Riseup's servers are in Paris, Amsterdam, Seattle, Miami, New York and Montreal. Takes effect at the next Super+u; vp says how many servers are left
| Padlock | In the bar while it's on: click for where you appear, right-click for a leak test
| Kill switch | Nothing can leave outside the VPN. If it drops, the internet stays blocked until you press Super+u (or Ctrl+C in its window), so you never fall back to your real address without noticing. Your own network (other computers, the router, your VMs) still works
| Fresh VPN config | Super+u and vp connect with the saved config, then quietly fetch a fresh one through the VPN for next time (the certificates last about a month; what it printed is in ~/.cache/vpn-fetch.log). Turning the VPN off stops a fetch still going. If the saved one is missing or runs out within a day, they fetch one first; if that fails and it has run out, the VPN doesn't start (the kill switch would block everything) and a notification says why
| VPN off | The internet works normally with your real address; only while the VPN's on does the kill switch block everything outside it
| DNS | With the VPN on, every name lookup goes to Quad9 through it, so your internet provider can't see which sites you visit
| Why | Sites see the VPN's address, not your home's; your provider sees only scrambled traffic to the VPN
| No password | The part that needs root is /usr/local/lib/vpn-root, allowed by a sudo rule for exactly that. It keeps only plain settings from the config (nothing that runs programs or touches files)
| The first time | (and after its source, ~/.local/lib/vpn-root, changes) Super+u opens a small window that asks your password once to install it; vp asks in the terminal instead

### Browser (Glide)

| Wiped on close | History, downloads list, form data and cache. Cookies stay, but each site gets its own jar, so sites can't follow you from one to another
| Network | HTTPS only, encrypted DNS (Mullvad; a lookup it can't answer goes to the normal DNS rather than failing the page), no prefetching, WebRTC can't leak your real IP
| Looking like everyone else | Sites see US English and UTC as the time zone; the browser's own region (search suggestions) is US and never looked up from your address, and code on pages uses the default monospace font (a custom one is a fingerprint). Canvas, WebGL and the window size are left as they were (protecting canvas broke images)
| No reporting | No telemetry, suggestions, sponsored content or location; strict tracking protection
| Links | Tracking bits stripped from links you copy anywhere (utm, fbclid, gclid, YouTube 'si', Amazon ref …)
| Add-ons | uBlock Origin, SponsorBlock, LibRedirect, a YouTube recommendations hider, Dark Reader, Pywalfox (wallpaper colours) and Video Speed Controller install themselves

### lk: encrypted drives

> lk sets up, mounts and unmounts encrypted (LUKS) drives, like the backup drive. It runs in a terminal and asks for your sudo password, since disk work needs root.

| lk setup (lk s) | Make a drive an encrypted drive that's yours: everything on it is erased, and it ends up as one encrypted partition (ext4), mounted
| Its questions | All asked first: which drive, a name for it, where to mount it (/mnt/hdd unless you change it), and whether to overwrite all of it. Then you type YES and choose its passphrase; the rest runs by itself
| Overwrite all of it | Asked as [Y/n], so Enter says yes (n skips it). Slow (it says about how long): fills the whole drive so nothing that was on it before can be recovered. Ctrl+C stops it, and lk setup can be run again
| lk mount (lk m) | Unlock and mount a drive. A drive lk knows only asks for its passphrase; a new one first asks a name and where to mount it. With several plugged in, you pick one
| lk unmount (lk u) | Unmount and lock it, so you can unplug it. If something is still using it, lk says which programs: close them (or cd out of it in that terminal) and run lk u again
| Never the system's disk | The disks the system runs from (/, /boot, /home, swap…) are never offered
| Where | Drives go on an empty folder under /mnt, /media, /run/media or your home folder
| Remembered | ~/.config/lk/drives, a line per drive: its ID, name and mount point. Edit a line to rename or move one; delete it to be asked again
| If it stops | Stopped partway (an error, Ctrl+C), the drive it opened is unmounted and locked again
| Pulled out while mounted | The drive is left stuck (its folder gives I/O errors and lk m says something is already mounted there). lk m and lk u notice it, clear what it left behind and carry on: lk m then mounts it again as usual
| Why | A lost or stolen drive gives nothing away without its passphrase
| The backup drive | Set it up with lk setup at /mnt/hdd

### backup: copies of your files on the backup drive

> backup keeps encrypted backups of your home folder on the backup drive, and copies any files or folders somewhere as they are. It runs in a terminal; if the drive isn't mounted, it offers to mount it (lk mount).

| backup | Back up the folders you usually pick (your whole home folder, less caches, Downloads, Videos and private, unless you change it) as one encrypted file on the drive. A list shows first: Enter backs up what's ticked
| The first time | It makes the backup key and asks you to choose its passphrase: restoring needs it (and only it). A copy of the key goes on the drive, so another computer can restore from it
| backup --pick | Choose what's backed up by default (Ctrl+S in the list saves it too)
| Kept | The newest backup of each day for 7 days, of each week for 4 weeks and of each month for 6 months. One-offs (not your usual folders): the newest 3
| backup list | The backups on the drive, oldest first, with their sizes
| backup restore [FILE] [DIR] | Unpack the newest backup (or FILE) into ~/restore-DATE (or DIR), after the key's passphrase. Nothing of yours is overwritten
| backup PATH… to DEST | Copy files or folders into DEST as they are (not encrypted): backup ~/backups to /mnt/hdd makes /mnt/hdd/backups. The "to" can be left out. Run again, it copies only what's new or changed, and never takes anything out of DEST
| Where | ~/.config/backup/config: BACKUP_DEST, /mnt/hdd/backup unless you change it. BACKUP_TO=HOST:FOLDER sends to another computer over SSH instead, as plain files kept in step with yours
| Before unplugging | lk u

### blank: wipe a drive like new

> blank erases a drive (a USB stick, an external disk) and makes it like new: one partition with the filesystem you pick, or nothing at all, ready to flash an ISO onto. It runs in a terminal and asks for your sudo password. For an encrypted drive, use lk setup instead (it wipes the drive itself).

| blank | Pick the drive (j/k move, Enter picks, q cancels), then what to make it, then its name (what you see when you plug it in; USB unless you change it)
| exFAT | Works on Windows, Mac, Linux, TVs and cameras, files of any size: best for most USBs
| FAT32 | Works on everything, even old devices and car stereos, but no file over 4 GB
| ext4 | Linux only. The drive is yours (no sudo needed to write to it)
| NTFS | Windows; a Mac can only read it
| blank | Wiped with no partition at all, ready for dd: sudo dd if=FILE.iso of=/dev/sdX bs=4M oflag=direct conv=fsync status=progress (dd overwrites everything anyway, so this is only for starting clean)
| Overwrite all of it | Asked as [Y/n], so Enter says yes (n skips it). Slow (it says about how long): zeros over the whole drive so nothing that was on it can be recovered
| Then | One YES, and the rest runs by itself: whatever on the drive is mounted, used as swap or unlocked is unmounted and locked, every old partition and signature (an ISO's too) is wiped, then it's partitioned (MBR under 2 TiB, for TVs and old computers; GPT above) and formatted
| Never the system's disk | The disks the system runs from (/, /boot, /home, swap…) are never offered
| An lk drive | Erasing one also takes it out of ~/.config/lk/drives
| If it stops | Before YES, nothing has changed. After, the drive may be left half-made: run blank again

### SSH key

| What | The SWAI installer makes ~/.ssh/id_ed25519 with the passphrase you give it at the start; the agent asks for it once per login
| Why | Logs you in to GitHub and servers without a password that could be phished or guessed; the private key never leaves the computer, and the passphrase protects it if the file is ever copied
| Use | cat ~/.ssh/id_ed25519.pub → paste into GitHub › Settings › SSH keys · ssh -T git@github.com tests it

### Other quiet protections

| Lock screen | Locks by itself after 45 minutes idle. Pauses media, mutes, wipes the clipboard, closes kp and locks KeePassXC
| Kernel | Programs can't read each other's memory (ptrace), kernel addresses and logs are hidden from normal programs, and unsafe kernel features (unprivileged BPF, kexec, line-discipline loading) are off. These are the doors most local attacks use
| Network | No TCP timestamps: sites can't use them to guess how long your computer has been on or to tell machines apart
| Nothing online by itself | No NetworkManager online check, no nightly news fetch, no weekly keyring refresh (update does it): after a boot, nothing reaches the internet until you open something
| No SSH server | Nothing can log in to this computer over the network (it wasn't used, and it accepted passwords). Once send receive has turned it on, it stays on
| Firewall | Nothing can connect in unless this computer started it (replies still get through). Let in: ping, getting an address, Syncthing, and SSH and NAME.local, which only answer once send receive has turned them on
| Nothing left on disk | No crash dumps (they can hold passwords from memory), system logs in RAM only, swap only in compressed RAM: a swap partition on this system's disk (the one / is on; other attached disks are left alone) is wiped and retyped so it never comes on at boot, once /etc/fstab no longer uses it, since what's swapped out could be passwords

## Tools and scripts

| speak | Audiobooks from books and writing: see the Audiobooks section
| yt-transcript [-c] [URL] [OUT] | Save a YouTube video's English captions as tidy text in the folder you're in, or to OUT (URL from the clipboard if none; -c also copies it). No English captions: YouTube's translation, about a minute's wait
| transcribe FILE… | Audio or video to Word and PDF: see Audiobooks
| record-screen [-r] [-m] [-n] [-p] | Record the screen (region, microphone, no sound, pause). Saved to ~/Videos
| watermark FILE | Brush out a watermark (or anything) with IOPaint's AI fill, in its own window; Save replaces FILE. Stops after saving, when you close the window, or after two hours unused
| clicker | Auto-clicker: clicker -i 50 -b right -j 10 -n 100 (interval, button, random jitter, count); clicker speed (Super+Shift+F6) sets it. Running a command again stops it; holding Super pauses it. clicker check says what's stopping it, if anything
| clicker macros | clicker record NAME, clicker play NAME -r 5 (or -l to loop, -t 600 for ten minutes) -s 2, clicker pick (choose one, Super+F11), clicker list / edit. Macros are plain text you can edit; a key held down plays back held
| Alt+m | Open your Accounting (~/sync/documents/Accounting/money.txt) in nvim
| pomo | Pomodoro (default 40 min work, 10 min break): pomo starts or pauses (Alt+p), skip, reset (Alt+Shift+p), show, status, set 50 10 (set 50 alone: a 10 min break; more numbers make a longer cycle, work and break in turn).
| wallpaper [IMAGE or FOLDER] | Random day/night wallpaper (as Super+b) / set that picture, or a random one from that folder, and recolour the whole desktop. wallpaper dir: the folder in use (wallpaper dir pick, or wallpaper dir set DIR session|always, changes it); wallpaper warm: work out colours ahead of time
| guide build | Rebuild System Guide.pdf from its source (~/Documents/.system-guide/guide.md) after editing it; Super+F9 opens the PDF (~/Documents/System Guide.pdf)
| settimes | Edit times.conf (night switch, red screen and dimming, pomodoro) and apply it. A value it can't read uses its default (a notification says which), and it offers to reopen the editor
| apphide NAME / -u / -l | Hide an app from the launcher / show it again / list hidden. Kept in your dotfiles
| dangerzone | Dangerzone with yazi and vim keys
| doc [-p] FILE… | Writing (markdown, notes, text) to a Word document in your house style; -p also a PDF that looks the same; -o OUT.pdf for just a PDF. A title / subtitle / author / date block at the top fills the heading. doc --style opens the house style (Arial, A4, plain headings) in LibreOffice to change it

### Night mode: red screen and dimming

| night-mode | At night the screen goes 40% red and as dim as it goes: from dim_start (01:00) to night_end (05:00). At dim_end (06:00) the brightness goes back to full. The dim timer runs it at those times; settimes changes them
| After a boot | Never red or dim straight after turning the computer on, even at night: only once dim_start comes round with it on (waking from sleep counts). Red you turned on by hand is gone after a reboot or shutdown too
| Super+Right / Super+Left | Redder / less red, any time of day (until night_end and dim_end turn it off), 10% a press (a notification shows the level); all the way down turns it off. dim_start always starts it at 40% again
| night-mode off | Normal colours now (red again at the next dim_start)
| nightred | The red itself: a small program that tints the screen, started and stopped by night-mode. It can't if another program already controls the screen's colours (like wlsunset)
## Keeping the system up to date

> Everything outside your home folder is set up by sys-setup, so a new machine ends up the same as this one.

| update | Full update, start to finish without stopping; asks for your password once, at the start
| What update does | Arch news since your last update (shown, without stopping), the keys that sign Arch's packages (once a week: about 30 seconds, and it says so), then system packages, then AUR updates if there are any (straight through, no questions), sys-setup, flatpaks, nvim and yazi plugins, cleanup. Last of all, a Flatpak section: each app that updated (old version → new), anything installed or removed, how many runtimes changed, or that nothing did
| Its checks | Missing libraries in mango or quickshell (it says what to run to rebuild), a new kernel (→ reboot), a mango that doesn't accept your config. An AUR program that a library update broke (sioyek after every mupdf update: "libmupdf.so… cannot open shared object file") is built again against the new library, so it starts again without you doing anything.
| sys-setup | Puts the system side in place. Safe to re-run; runs on every update (on a new machine, run it once yourself)
| What it sets up | Needed packages (and yt-dlp-git, pywal16), Dangerzone (picking files with yazi), ani-cli and ani-skip, clicker access, nvim plugins, login screen settings, hidden apps, LibreOffice defaults
| What it locks down | The firewall, hardening, Arch's own password lockout (3 wrong tries locks sudo for 10 minutes), no online checks, the SSH server off unless send receive turned it on, the ssh agent, Downloads scrubbing, RAM-only logs, zram swap, the clock kept right from a time server
| Free software only | sys-setup keeps out what isn't free software: no 7-Zip (its RAR code isn't free; libarchive does archives instead) and no Fraunhofer AAC library (only Bluetooth AAC headphone sound used it; the free codecs remain), and updates never bring them back. Exceptions you chose: Vesktop's Discord service and hardware firmware
| Its clean-up | After a system update that went through, it frees space: orphan packages, package caches, old logs, app and browser caches, unused caches (never speak, transcribe, books or IOPaint's model), bin. Then tidies: Python package downloads (uv), caches of apps no longer installed, and unused container images (never Dangerzone's)
| ud | Publish folders in ~/github to GitHub: U on the selected folders in yazi, ud alone lists them (j/k move, Space ticks, a ticks all, u changes your GitHub username), or ud NAME…; it publishes to the GitHub username you typed (the very first time, ud starts by asking it; never guessed); each one fresh commit with no history, secret scan first (if gitleaks finds something it shows it and asks before pushing), the SSH passphrase asked once. The repo has to exist on GitHub already (github.com/new)

## Default apps

| PDF and e-books (EPUB, MOBI, FB2, CBZ, XPS) | sioyek
| Text and code | Neovim in kitty
| Images | swayimg
| Video / audio | mpv / small mpv audio window (in ~/Audiobooks: Books)
| Audiobooks (.m4b) | Books
| Word, Excel, PowerPoint, ODF | LibreOffice
| Web links, HTML | Glide (YouTube links ask: FreeTube or Glide)
| Email links, .eml files | Thunderbird
| Folders | yazi
| Password databases | kp from yazi (KeePassXC from other apps, or as yazi's second choice)
| Discord links | Vesktop

### LibreOffice

| Saves as | Word, Excel and PowerPoint unless you pick another format, without asking each time
| Privacy | Saved files carry no author name, editing time, or names on comments and tracked changes
| Quiet | No backup copies, tips, donation or 'get involved' bars. Writer, Calc, Impress, Base, Draw and Math are hidden from the launcher (the LibreOffice start centre still shows); documents open in them from yazi
| Your changes win | These are defaults set by sys-setup: anything you change in Tools > Options wins

### Other apps

| btop | System monitor with vim keys and wallpaper colours (changes made in its menu last until it closes)
| fastfetch (f) | System summary
| SimpleX Chat | Private messenger (a flatpak): no phone number or user ID
