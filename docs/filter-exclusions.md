# Compact filter exclusions

The picker stores the smaller side of a catalog selection. Selecting all 11,435 narrators and clearing two sends `rawi[]=0&xrawi[]=1&xrawi[]=2` rather than 11,433 included IDs. Grades keep their four local inclusion options.

The API must support `xrawi[]`, `xm[]`, and `xs[]` on `/v1/site/hadith/search`. Responses must confirm `metadata.exclusionsApplied: true`; otherwise the app reports that the server needs updating and does not display unfiltered results. Deploy the API change before distributing the app update.

Exclusions are saved separately under `searchFilterExclusions`. Large inclusion lists saved by older versions are compacted against the catalog before their next search, or when the picker loads. Disabling saved filters removes both saved inclusion and exclusion lists.

API pages retain their upstream page numbers. Exclusions can empty a page while `hasNextPage` remains true, so the view model advances until it finds matches, reaches the final page, or encounters an error. A new search cancels traversal for the old query. Pagination snapshots preserve both inclusion and exclusion lists when the controls change.

The API matches narrator exclusions against complete catalog labels because Dorar does not expose narrator IDs on result cards. Display brackets and whitespace are normalized; compound labels remain distinct. Identical narrator labels are treated as the same narrator.

Verification:

```sh
flutter test test/compact_exclusions_test.dart test/search_option_picker_test.dart
```

The tests cover an 11,435-entry catalog, compact requests, restored checkbox states, saved-filter migration, pagination through empty pages, cancellation, and rejecting older servers that ignore exclusions. The picker performance test counts ID reads to catch quadratic matching without relying on device timing.
