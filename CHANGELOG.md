# Changelog

## [0.1.2] - unreleased

- **Each card says where its video is**, with badges on the picture: Desktop, Lock Screen, Screen Saver (as macOS has
  them, so a wallpaper picked in System Settings shows too). The blue frame around the desktop's video is gone.
- **A click on a card asks where the video goes:** Set as Wallpaper (the desktop and the Lock Screen), or Show On ›
  Desktop, Lock Screen and Menu Bar, Screen Saver, ticked where it is now. Unticking Desktop takes the video off the
  desktop, so macOS's own wallpaper shows there. A right-click opens the same menu.
- **Placing a video on the Lock Screen says it's busy** under the grid until macOS has it (converting it and restarting
  macOS's wallpaper service takes a few seconds).
- Find Videos moved to the bottom of the window, away from the toolbar's own buttons.
- The Lock Screen item says Menu Bar too: on a Mac the Lock Screen is the system wallpaper, which also colours the menu
  bar, so a video on the Lock Screen only still sets the menu bar's colours.

## [0.1.1] - 2026-10-25

- **The Lock Screen moves with the desktop.** Clicking a video makes it macOS's own wallpaper as W-Player's video
  wallpaper (macOS 26), not a still frame: it plays on the Lock Screen, and the menu bar takes its colours. The screen
  saver stays as it was. 0.1.0 set the first frame, which stood still on the Lock Screen. On older macOS the first frame
  is still what W-Player sets.
- **One place at a time, if you like.** The … button on a card (or a right-click) has Set as Wallpaper, Desktop Only,
  Lock Screen Only and Use as Screen Saver.
- **Labels say where a video is**, as macOS has it: DESKTOP, LOCK SCREEN, SCREEN SAVER. A wallpaper picked in System
  Settings shows up on the cards too. The lock button is gone: W-Player adds a video to System Settings › Wallpaper
  when it is used there and takes it out when it no longer is.
- The sound button shows only on videos that have sound.
- **Settings in the window:** a gear in the library's toolbar. Settings › Wallpaper has Restore Wallpaper and Quit.

## [0.1.0] - 2026-10-25

- **Your video on the desktop.** Add a video (drop it on the window, use Add Video, or open it with W-Player) and it
  plays under the desktop icons on every screen and every Space, muted and looping.
- **Stops when nobody sees it.** The wallpaper pauses while the screen is locked or asleep, when a full-screen app
  covers the desktop, in Low Power Mode, and, if you ask for it in Settings, on battery power. It doesn't keep the
  display awake.
- **Lock Screen and screen saver (macOS 26).** Right-click a video and choose Use on Lock Screen: it shows up in
  System Settings › Wallpaper under W-Player. W-Player keeps its entries there in order: it puts them back after a macOS
  update or another wallpaper app rewrites the list, and takes out broken entries that would hide all of Apple's videos.
- **The menu bar matches.** W-Player sets the video's first frame as macOS's own wallpaper, so the menu bar and
  Mission Control take its colours (Settings › Match the system wallpaper to the video).
- **Silent unless you ask.** Videos play without sound; the speaker button on a card turns one video's sound on. A muted
  video doesn't even load its audio, so the speakers stay off.
- **A welcome** that says W-Player runs in the background from the menu bar, what it pauses for, and where to find
  videos (Find Videos: Pexels, Pixabay, MoeWalls, MotionBGs).
- **Restore Wallpaper and Quit** in the menu bar puts back the wallpaper and screen saver you had before W-Player and
  takes its videos out of System Settings.
- **Updates in the app.** Check for Updates… in the menu bar, and an automatic check you can turn off in Settings
  (Sparkle 2.10.0; updates are signed and checked against the key in the app).
- A Dock icon while the library window is open; a menu bar item with Pause, the library and Settings the rest of the
  time; speed (½×, ¾×, normal); Open at Login; Lock Screen and sound buttons on each card.
