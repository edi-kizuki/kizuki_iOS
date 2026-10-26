# Repository contract recordings


B01 permits zero JSON recordings. The test bundle copies this directory unchanged. The replay suite reads every `*.json`, intercepts every SDK request, and compares decoded output plus the HTTP method, path and query. Missing directories and unsupported operations fail.

The current v1 format in `../ContractReplay.swift` supports `profile.own`. Use stable user UUID `00000000-0000-0000-0000-000000000042`. Include `version`, `operation`, `userID`, `request` (`method`, `path`, `query`), `response` (`status`, JSON `body` string), and `expected` (`profile` or null, `fails`). Profiles use snake_case lifecycle keys and JSONDecoder date numbers. Responses use the actual PostgREST date strings. No tokens, auth response bodies or user content belong here.

B02+ owns the real recording/normalization pipeline. Add operation handlers as repositories become live; do not create invented recordings and describe them as server evidence.
