# Audio Player Providers Test Document

### 1. Unit Test Plan Format
| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-AUD-PROV-01 | audio_player_providers.dart | audioTagsProvider | fetch tags from AudioMetadataUtils when no override exists | Mock AudioMetadataUtils to return a Tag | Read audioTagsProvider for a path | Returns the mocked tag |
| U-AUD-PROV-02 | audio_player_providers.dart | audioTagsProvider | return overridden tag if present | Set override tag in audioTagsOverridesProvider | Read audioTagsProvider | Returns the override tag |
| U-AUD-PROV-03 | audio_player_providers.dart | audioTagsProvider | return null when AudioMetadataUtils returns null and no override | Mock AudioMetadataUtils to return null | Read audioTagsProvider | Returns null |
| U-AUD-PROV-04 | audio_player_providers.dart | audioTagsProvider | prioritize override over disk tag even when both exist | Set both override and mock disk tag | Read audioTagsProvider | Returns override tag, not disk tag |
| U-AUD-PROV-05 | audio_player_providers.dart | audioTagsOverridesProvider | default to null for any path | Create fresh provider | Read audioTagsOverridesProvider('any/path') | Returns null |
| U-AUD-PROV-06 | audio_player_providers.dart | audioTagsOverridesProvider | maintain independent overrides per path | Set overrides for path A and path B | Read both | Each returns its own override |
| U-AUD-PROV-07 | audio_player_providers.dart | AudioFavoritesNotifier.toggleFavorite | add a path to favorites if not present | Initialize provider with empty state | Call toggleFavorite with path A | State contains path A |
| U-AUD-PROV-08 | audio_player_providers.dart | AudioFavoritesNotifier.toggleFavorite | remove a path from favorites if already present | Initialize provider with path A | Call toggleFavorite with path A | State does not contain path A |
| U-AUD-PROV-09 | audio_player_providers.dart | AudioFavoritesNotifier.toggleFavorite | maintain other favorites when toggling one | Initialize with paths A, B | Call toggleFavorite with path A | State contains B but not A |
| U-AUD-PROV-10 | audio_player_providers.dart | AudioFavoritesNotifier._init | load favorites from Hive box on initialization | Mock Hive box with ['pathA', 'pathB'] | Construct AudioFavoritesNotifier | State contains both paths |
| U-AUD-PROV-11 | audio_player_providers.dart | AudioFavoritesNotifier.toggleFavorite | persist favorites to Hive box on toggle | Mock Hive box | Call toggleFavorite with path A | verify Hive box.put('favorites', ...) is called |
| U-AUD-PROV-12 | audio_player_providers.dart | AudioFavoritesNotifier._init | default to empty set when Hive box is empty | Mock Hive box returning empty list | Construct AudioFavoritesNotifier | State is empty set |
| U-AUD-PROV-13 | audio_player_providers.dart | currentTrackProvider | return correct file item based on activeTrackIndex | Provide queue with 3 items, set index to 1 | Read currentTrackProvider | Returns item at index 1 |
| U-AUD-PROV-14 | audio_player_providers.dart | currentTrackProvider | return null if activeTrackIndex is out of bounds (too large) | Provide queue with 2 items, set index to 5 | Read currentTrackProvider | Returns null |
| U-AUD-PROV-15 | audio_player_providers.dart | currentTrackProvider | return null if activeTrackIndex is negative | Provide queue with 2 items, set index to -1 | Read currentTrackProvider | Returns null |
| U-AUD-PROV-16 | audio_player_providers.dart | currentTrackProvider | return null when queue is empty | Provide empty queue, set index to 0 | Read currentTrackProvider | Returns null |
| U-AUD-PROV-17 | audio_player_providers.dart | currentTrackProvider | return first item when index is 0 and queue has items | Provide queue with 3 items, set index to 0 | Read currentTrackProvider | Returns first item |
| U-AUD-PROV-18 | audio_player_providers.dart | currentTrackProvider | watch both queue and index reactively | Change queue or index after initial read | Read currentTrackProvider again | Returns updated result |
| U-AUD-PROV-19 | audio_player_providers.dart | filteredAndSortedAudioQueueProvider | filter queue by favorites view mode | Set viewMode to favorites, queue with fav and non-fav items | Read filteredAndSortedAudioQueueProvider | Returns only favorite items |
| U-AUD-PROV-20 | audio_player_providers.dart | filteredAndSortedAudioQueueProvider | return all items in home view mode | Set viewMode to home, queue with 5 items | Read filteredAndSortedAudioQueueProvider | Returns all 5 items |
| U-AUD-PROV-21 | audio_player_providers.dart | filteredAndSortedAudioQueueProvider | filter queue by search query (case-insensitive) | Set search query to 'Song', queue with "Song_A.mp3", "track_b.mp3", "SONG_c.mp3" | Read filteredAndSortedAudioQueueProvider | Returns "Song_A.mp3" and "SONG_c.mp3" |
| U-AUD-PROV-22 | audio_player_providers.dart | filteredAndSortedAudioQueueProvider | return all items when search query is empty | Set search query to '', queue with items | Read filteredAndSortedAudioQueueProvider | Returns all items |
| U-AUD-PROV-23 | audio_player_providers.dart | filteredAndSortedAudioQueueProvider | sort queue by name A to Z with folders first | Set sortOption to aToZ, provide unsorted queue with mixed folders and files | Read filteredAndSortedAudioQueueProvider | Returns folders first (sorted A-Z), then files (sorted A-Z) |
| U-AUD-PROV-24 | audio_player_providers.dart | filteredAndSortedAudioQueueProvider | sort queue by name Z to A with folders first | Set sortOption to zToA, provide unsorted queue with mixed folders and files | Read filteredAndSortedAudioQueueProvider | Returns folders first (sorted Z-A), then files (sorted Z-A) |
| U-AUD-PROV-25 | audio_player_providers.dart | filteredAndSortedAudioQueueProvider | sort queue by last modified (newest first) | Set sortOption to lastModified, provide mixed dates | Read filteredAndSortedAudioQueueProvider | Returns queue sorted by newest first, folders still before files |
| U-AUD-PROV-26 | audio_player_providers.dart | filteredAndSortedAudioQueueProvider | sort queue by first modified (oldest first) | Set sortOption to firstModified, provide mixed dates | Read filteredAndSortedAudioQueueProvider | Returns queue sorted by oldest first, folders still before files |
| U-AUD-PROV-27 | audio_player_providers.dart | filteredAndSortedAudioQueueProvider | sort queue by size large to small | Set sortOption to sizeLargeToSmall, provide mixed size queue | Read filteredAndSortedAudioQueueProvider | Returns queue sorted by size descending, folders before files |
| U-AUD-PROV-28 | audio_player_providers.dart | filteredAndSortedAudioQueueProvider | sort queue by size small to large | Set sortOption to sizeSmallToLarge, provide mixed size queue | Read filteredAndSortedAudioQueueProvider | Returns queue sorted by size ascending, folders before files |
| U-AUD-PROV-29 | audio_player_providers.dart | filteredAndSortedAudioQueueProvider | sort queue by files first (folders after files, sorted A-Z) | Set sortOption to filesFirst, provide mixed folders and files | Read filteredAndSortedAudioQueueProvider | Returns files before folders, each group sorted A-Z |
| U-AUD-PROV-30 | audio_player_providers.dart | filteredAndSortedAudioQueueProvider | handle null sizeBytes when sorting by size | Set sortOption to sizeLargeToSmall, items with null sizeBytes | Read filteredAndSortedAudioQueueProvider | Null sizeBytes treated as 0, no exception |
| U-AUD-PROV-31 | audio_player_providers.dart | filteredAndSortedAudioQueueProvider | preserve original order when sortOption is null | Set sortOption to null, provide unsorted queue | Read filteredAndSortedAudioQueueProvider | Returns queue in original order |
| U-AUD-PROV-32 | audio_player_providers.dart | filteredAndSortedAudioQueueProvider | handle combined filter and sort | Set search query to 'song', viewMode to favorites, sort by aToZ | Read filteredAndSortedAudioQueueProvider | Returns only favorite items matching 'song', sorted A-Z |
| U-AUD-PROV-33 | audio_player_providers.dart | filteredAndSortedAudioQueueProvider | return empty list when no items match search | Set search query to 'nonexistent', queue with items | Read filteredAndSortedAudioQueueProvider | Returns empty list |
| U-AUD-PROV-34 | audio_player_providers.dart | filteredAndSortedAudioQueueProvider | return empty list when no favorites exist in favorites mode | Set viewMode to favorites, empty favorites set, queue with items | Read filteredAndSortedAudioQueueProvider | Returns empty list |
| U-AUD-PROV-35 | audio_player_providers.dart | audioPositionProvider | emit position updates from player stream | Mock player.stream.position | Listen to audioPositionProvider | Emits correct Duration values |
| U-AUD-PROV-36 | audio_player_providers.dart | audioDurationProvider | emit duration updates from player stream | Mock player.stream.duration | Listen to audioDurationProvider | Emits correct Duration values |
| U-AUD-PROV-37 | audio_player_providers.dart | audioPlayingProvider | emit playing status from player stream | Mock player.stream.playing | Listen to audioPlayingProvider | Emits correct boolean values |
| U-AUD-PROV-38 | audio_player_providers.dart | audioVolumeProvider | emit volume updates from player stream | Mock player.stream.volume | Listen to audioVolumeProvider | Emits correct double values |
| U-AUD-PROV-39 | audio_player_providers.dart | Stream Providers (all 4) | emit empty stream when player is null | Leave audioPlayerProvider null | Listen to all 4 stream providers | Each emits empty stream |
| U-AUD-PROV-40 | audio_player_providers.dart | audioShowHiddenProvider | initialize from settings provider when true | Mock settings with showHiddenAudioFiles = true | Read audioShowHiddenProvider | Returns true |
| U-AUD-PROV-41 | audio_player_providers.dart | audioShowHiddenProvider | initialize from settings provider when false | Mock settings with showHiddenAudioFiles = false | Read audioShowHiddenProvider | Returns false |
| U-AUD-PROV-42 | audio_player_providers.dart | audioShowHiddenProvider | default to false when settings provider has no value | Mock settings provider returning null AsyncValue | Read audioShowHiddenProvider | Returns false |
| U-AUD-PROV-43 | audio_player_providers.dart | audioViewModeProvider | default to AudioViewMode.home | Create fresh provider | Read audioViewModeProvider | Returns AudioViewMode.home |
| U-AUD-PROV-44 | audio_player_providers.dart | audioPlayerProvider | default to null | Create fresh provider | Read audioPlayerProvider | Returns null |
| U-AUD-PROV-45 | audio_player_providers.dart | audioCurrentPathProvider | default to empty string | Create fresh provider | Read audioCurrentPathProvider | Returns '' |
| U-AUD-PROV-46 | audio_player_providers.dart | audioRootPathProvider | default to empty string | Create fresh provider | Read audioRootPathProvider | Returns '' |
| U-AUD-PROV-47 | audio_player_providers.dart | audioPathHistoryProvider | default to empty list | Create fresh provider | Read audioPathHistoryProvider | Returns [] |
| U-AUD-PROV-48 | audio_player_providers.dart | audioPathForwardHistoryProvider | default to empty list | Create fresh provider | Read audioPathForwardHistoryProvider | Returns [] |
| U-AUD-PROV-49 | audio_player_providers.dart | audioSelectionProvider | default to empty set | Create fresh provider | Read audioSelectionProvider | Returns {} |
| U-AUD-PROV-50 | audio_player_providers.dart | audioSelectionAnchorProvider | default to null | Create fresh provider | Read audioSelectionAnchorProvider | Returns null |
| U-AUD-PROV-51 | audio_player_providers.dart | audioQueueProvider | default to empty list | Create fresh provider | Read audioQueueProvider | Returns [] |
| U-AUD-PROV-52 | audio_player_providers.dart | audioPlayingQueueProvider | default to empty list | Create fresh provider | Read audioPlayingQueueProvider | Returns [] |
| U-AUD-PROV-53 | audio_player_providers.dart | activeTrackIndexProvider | default to 0 | Create fresh provider | Read activeTrackIndexProvider | Returns 0 |
| U-AUD-PROV-54 | audio_player_providers.dart | audioIsReloadingProvider | default to false | Create fresh provider | Read audioIsReloadingProvider | Returns false |
| U-AUD-PROV-55 | audio_player_providers.dart | audioSortOptionProvider | default to null | Create fresh provider | Read audioSortOptionProvider | Returns null |
| U-AUD-PROV-56 | audio_player_providers.dart | audioSearchQueryProvider | default to empty string | Create fresh provider | Read audioSearchQueryProvider | Returns '' |
| U-AUD-PROV-57 | audio_player_providers.dart | globalAudioPlayer | be a non-null Player instance | Access globalAudioPlayer | Read globalAudioPlayer | Is not null, is a Player instance |

### 2. Widget Test Plan Format
N/A - Pure Logic
