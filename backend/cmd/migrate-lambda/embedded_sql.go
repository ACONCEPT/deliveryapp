package main

import (
	_ "embed"
)

// Embed SQL files at compile time
// These files will be embedded into the binary
//
// NOTE: The SQL files (schema.sql, drop_all.sql) are copied from ../../sql/
// during the build process (see build.sh). Do not manually edit the local copies.
// The source of truth is in backend/sql/

//go:embed schema.sql
var schemaSQL string

//go:embed drop_all.sql
var dropAllSQL string
