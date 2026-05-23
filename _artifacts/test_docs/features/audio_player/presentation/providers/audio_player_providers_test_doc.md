# Audio Player Providers Test Document

### 1. Unit Test Plan Format
| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-AUD-PROV-01 | audio_player_providers.dart | audioTagsProvider | fetch tags from AudioMetadataUtils when no override exists | Mock AudioMetadataUtils to return a Tag | Read audioTagsProvider for a path | Returns the mocked tag |
| U-AUD-PROV-02 | audio_player_providers.dart | audioTagsProvider | return overridden tag if present | Set override tag in audioTagsOverridesProvider | Read audioTagsProvider | Returns the override tag |
| U-AUD-PROV-03 | audio_player_providers.dart | AudioFavoritesNotifier.toggleFavorite | add a path to favorites if not present | Initialize provider with empty state | Call toggleFavorite with path A | State contains path A |
| U-AUD-PROV-04 | audio_player_providers.dart | AudioFavoritesNotifier.toggleFavorite | remove a path from favorites if already present | Initialize provider with path A | Call toggleFavorite with path A | State does not contain path A |
| U-AUD-PROV-05 | audio_player_providers.dart | currentTrackProvider | return correct file item based on activeTrackIndex | Provide queue with 3 items, set index to 1 | Read currentTrackProvider | Returns item at index 1 |
| U-AUD-PROV-06 | audio_player_providers.dart | currentTrackProvider | return null if activeTrackIndex is out of bounds | Provide queue with 2 items, set index to 5 | Read currentTrackProvider | Returns null |
| U-AUD-PROV-07 | audio_player_providers.dart | filteredAndSortedAudioQueueProvider | filter queue by favorites view mode | Set viewMode to favorites, queue with fav and non-fav items | Read filteredAndSortedAudioQueueProvider | Returns only favorite items |
| U-AUD-PROV-08 | audio_player_providers.dart | filteredAndSortedAudioQueueProvider | filter queue by search query | Set search query to 'song', queue with matching/non-matching items | Read filteredAndSortedAudioQueueProvider | Returns only items matching 'song' |
| U-AUD-PROV-09 | audio_player_providers.dart | filteredAndSortedAudioQueueProvider | sort queue by size large to small | Set sortOption to sizeLargeToSmall, provide mixed size queue | Read filteredAndSortedAudioQueueProvider | Returns queue sorted by size descending |
| U-AUD-PROV-10 | audio_player_providers.dart | filteredAndSortedAudioQueueProvider | handle combined filter and sort | Set search query, viewMode to favorites, sort by name | Read filteredAndSortedAudioQueueProvider | Returns correctly filtered and sorted queue |
| U-AUD-PROV-11 | audio_player_providers.dart | filteredAndSortedAudioQueueProvider | sort queue by name A to Z | Set sortOption to aToZ, provide unsorted queue | Read filteredAndSortedAudioQueueProvider | Returns queue sorted alphabetically |
| U-AUD-PROV-12 | audio_player_providers.dart | filteredAndSortedAudioQueueProvider | sort queue by name Z to A | Set sortOption to zToA, provide unsorted queue | Read filteredAndSortedAudioQueueProvider | Returns queue sorted reverse alphabetically |
| U-AUD-PROV-13 | audio_player_providers.dart | filteredAndSortedAudioQueueProvider | sort queue by last modified | Set sortOption to lastModified, provide mixed dates | Read filteredAndSortedAudioQueueProvider | Returns queue sorted by newest first |
| U-AUD-PROV-14 | audio_player_providers.dart | filteredAndSortedAudioQueueProvider | sort queue by first modified | Set sortOption to firstModified, provide mixed dates | Read filteredAndSortedAudioQueueProvider | Returns queue sorted by oldest first |
| U-AUD-PROV-15 | audio_player_providers.dart | filteredAndSortedAudioQueueProvider | sort queue by files first | Set sortOption to filesFirst, provide mixed folders and files | Read filteredAndSortedAudioQueueProvider | Returns queue with files before folders |
| U-AUD-PROV-16 | audio_player_providers.dart | filteredAndSortedAudioQueueProvider | ensure folders come first in standard sort | Set sortOption to aToZ, provide mixed folders and files | Read filteredAndSortedAudioQueueProvider | Returns queue with folders before files |
| U-AUD-PROV-17 | audio_player_providers.dart | audioPositionProvider | emit position updates from player stream | Mock player.stream.position | Listen to audioPositionProvider | Emits correct Duration values |
| U-AUD-PROV-18 | audio_player_providers.dart | audioDurationProvider | emit duration updates from player stream | Mock player.stream.duration | Listen to audioDurationProvider | Emits correct Duration values |
| U-AUD-PROV-19 | audio_player_providers.dart | audioPlayingProvider | emit playing status from player stream | Mock player.stream.playing | Listen to audioPlayingProvider | Emits correct boolean values |
| U-AUD-PROV-20 | audio_player_providers.dart | audioVolumeProvider | emit volume updates from player stream | Mock player.stream.volume | Listen to audioVolumeProvider | Emits correct double values |
| U-AUD-PROV-21 | audio_player_providers.dart | Stream Providers | emit empty stream when player is null | Leave audioPlayerProvider null | Listen to stream providers | Emits empty stream |
| U-AUD-PROV-22 | audio_player_providers.dart | audioShowHiddenProvider | initialize from settings provider | Mock settings with showHiddenAudioFiles = true | Read audioShowHiddenProvider | Returns true |

### 2. Widget Test Plan Format
N/A - Pure Logic
