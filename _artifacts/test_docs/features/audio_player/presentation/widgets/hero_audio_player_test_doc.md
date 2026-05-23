# Hero Audio Player Test Document

### 1. Unit Test Plan Format
N/A - UI and Integration Logic

### 2. Widget Test Plan Format
| Test ID | File(s) Under Test | Target Widget / State | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-AUD-HERO-01 | hero_audio_player.dart | HeroAudioPlayer | return SizedBox.shrink when currentTrack is null | Mock currentTrackProvider returning null | Render widget | Finds SizedBox.shrink, no album art or controls |
| W-AUD-HERO-02 | hero_audio_player.dart | HeroAudioPlayer | display cover art from ID3 tag pictures | Mock currentTrack with tag containing picture bytes | Render widget | Finds Image.memory widget with correct bytes |
| W-AUD-HERO-03 | hero_audio_player.dart | HeroAudioPlayer | display gradient music note fallback when no cover art | Mock currentTrack with tag lacking pictures | Render widget | Finds Icons.music_note_rounded with size=140, wrapped in ShaderMask |
| W-AUD-HERO-04 | hero_audio_player.dart | HeroAudioPlayer | display gradient music note fallback when tag is null | Mock currentTrack with null tag | Render widget | Finds Icons.music_note_rounded fallback |
| W-AUD-HERO-05 | hero_audio_player.dart | HeroAudioPlayer | render ShaderMask with magenta→violet gradient on fallback icon | Mock currentTrack without cover art | Render widget | Finds ShaderMask with LinearGradient from AppColors.magenta to AppColors.violet |
| W-AUD-HERO-06 | hero_audio_player.dart | HeroAudioPlayer | render gradient overlay on cover art (white 15% → black 40%) | Mock currentTrack with cover art | Render widget | Finds Stack with Container having LinearGradient stops [0.0, 0.3, 0.7, 1.0] |
| W-AUD-HERO-07 | hero_audio_player.dart | HeroAudioPlayer | constrain album art to 380x380 max size | Mock currentTrack | Render widget | Finds ConstrainedBox with maxWidth=380, maxHeight=380 |
| W-AUD-HERO-08 | hero_audio_player.dart | HeroAudioPlayer | enforce 1:1 aspect ratio on album art | Mock currentTrack | Render widget | Finds AspectRatio with aspectRatio=1.0 |
| W-AUD-HERO-09 | hero_audio_player.dart | HeroAudioPlayer | render album art container with border and shadow | Mock currentTrack | Render widget | verify Container has border width=1.5, borderRadius=16, boxShadow blurRadius=40, spreadRadius=10 |
| W-AUD-HERO-10 | hero_audio_player.dart | HeroAudioPlayer | display track name without extension | Mock currentTrack with name "Song_Title.mp3" | Render widget | Finds "Song_Title" text in AutoScrollingText, not "Song_Title.mp3" |
| W-AUD-HERO-11 | hero_audio_player.dart | HeroAudioPlayer | display "Artist \| Album" subtitle when both present | Mock tag with trackArtist="Artist A" and album="Album B" | Render widget | Finds Text "Artist A \| Album B" |
| W-AUD-HERO-12 | hero_audio_player.dart | HeroAudioPlayer | display only artist when album is null/empty | Mock tag with trackArtist="Artist A" and album=null | Render widget | Finds Text "Artist A" |
| W-AUD-HERO-13 | hero_audio_player.dart | HeroAudioPlayer | display only album when artist is null/empty | Mock tag with trackArtist=null and album="Album B" | Render widget | Finds Text "Album B" |
| W-AUD-HERO-14 | hero_audio_player.dart | HeroAudioPlayer | display "Audio File" fallback when both artist and album missing | Mock tag with both null | Render widget | Finds Text "Audio File" |
| W-AUD-HERO-15 | hero_audio_player.dart | HeroAudioPlayer | prioritize override tag over async tag | Set audioTagsOverridesProvider with different tag | Render widget | verify UI displays override tag's artist/album, not async tag's |
| W-AUD-HERO-16 | hero_audio_player.dart | HeroAudioPlayer | render subtitle with white38 color and 16px font | Mock any track | Render widget | Finds subtitle Text with color Colors.white38, fontSize 16, fontWeight w500 |
| W-AUD-HERO-17 | hero_audio_player.dart | HeroAudioPlayer | render track name with 28px bold, -0.5 letter-spacing | Mock any track | Render widget | verify AutoScrollingText style has fontSize=28, fontWeight=bold, letterSpacing=-0.5 |
| W-AUD-HERO-18 | hero_audio_player.dart | HeroAudioPlayer | include WaveformScrubber with correct fileName | Mock currentTrack named "test.mp3" | Render widget | Finds WaveformScrubber with fileName="test.mp3" |
| W-AUD-HERO-19 | hero_audio_player.dart | HeroAudioPlayer | include AudioControlsBar | Mock currentTrack | Render widget | Finds AudioControlsBar widget |
| W-AUD-HERO-20 | hero_audio_player.dart | HeroAudioPlayer | use gaplessPlayback for smooth cover art transitions | Mock currentTrack with cover art | Render widget | verify Image.memory has gaplessPlayback=true |
| W-AUD-HERO-21 | hero_audio_player.dart | HeroAudioPlayer | use Spacer flex layout (3, 10, 2, 2, 1, 2) | Mock any track | Render widget | verify Column children have Spacer with expected flex values |
| W-AUD-HERO-22 | hero_audio_player.dart | AutoScrollingText | initialize scrolling after 2 second delay | Render AutoScrollingText with text "Test Long Title That Overflows" | Wait 2 seconds | verify Ticker started, scroll controller begins jumping |
| W-AUD-HERO-23 | hero_audio_player.dart | AutoScrollingText | not start scrolling before 2 seconds | Render AutoScrollingText | Wait 1 second | verify Ticker is NOT active yet |
| W-AUD-HERO-24 | hero_audio_player.dart | AutoScrollingText | reset scroll position and re-delay when text changes | Render AutoScrollingText, change text prop | Update widget text from "Song A" to "Song B" | verify _offset reset to 0.0, scroll controller jumps to 0, ticker stopped and re-delayed |
| W-AUD-HERO-25 | hero_audio_player.dart | AutoScrollingText | not restart when text stays the same | Render AutoScrollingText, rebuild with same text | Update widget with same text | verify _offset NOT reset, ticker continues |
| W-AUD-HERO-26 | hero_audio_player.dart | AutoScrollingText | scroll at ~1px per frame (~60px/sec at 60fps) | Start ticker | Accumulate 10 frames | verify _offset incremented by ~10px |
| W-AUD-HERO-27 | hero_audio_player.dart | AutoScrollingText | render as horizontal ListView with NeverScrollableScrollPhysics | Render widget | Mount widget | Finds ListView with horizontal direction and NeverScrollableScrollPhysics |
| W-AUD-HERO-28 | hero_audio_player.dart | AutoScrollingText | use fixed 36px height SizedBox | Render widget | Mount widget | Finds SizedBox with height=36 |
| W-AUD-HERO-29 | hero_audio_player.dart | AutoScrollingText | add 64px right padding between repeating text items | Render widget | Mount widget | verify Container has padding right=64 |
| W-AUD-HERO-30 | hero_audio_player.dart | AutoScrollingText | dispose ticker and scroll controller on unmount | Mount then unmount widget | Unmount AutoScrollingText | verify ticker and scrollController are disposed without error |
| W-AUD-HERO-31 | hero_audio_player.dart | AutoScrollingText | handle missing scroll clients gracefully | Start ticker before layout completes | Tick fires | verify no exception when _scrollController.hasClients is false |
