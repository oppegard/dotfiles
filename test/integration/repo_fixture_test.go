package integration

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func copyTrackedFiles(t *testing.T, source, dest, nulSeparatedNames string) {
	t.Helper()
	for _, name := range strings.Split(strings.TrimSuffix(nulSeparatedNames, "\x00"), "\x00") {
		if name == "" {
			continue
		}
		from := filepath.Join(source, name)
		to := filepath.Join(dest, name)
		info, err := os.Lstat(from)
		if errors.Is(err, os.ErrNotExist) {
			continue
		}
		if err != nil {
			t.Fatal(err)
		}
		if !info.Mode().IsRegular() {
			t.Fatalf("tracked path %q is not a regular file", name)
		}
		contents, err := os.ReadFile(from)
		if err != nil {
			t.Fatal(err)
		}
		if err := os.MkdirAll(filepath.Dir(to), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(to, contents, info.Mode().Perm()); err != nil {
			t.Fatal(err)
		}
	}
}
