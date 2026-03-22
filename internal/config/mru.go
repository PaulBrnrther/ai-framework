package config

import (
	"os"
	"sort"
	"strings"
)

// ReadMRU reads the MRU list from a file. Returns empty slice if file missing.
func ReadMRU(path string) []string {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	var result []string
	for _, e := range strings.Split(strings.TrimSpace(string(data)), "\n") {
		if e != "" {
			result = append(result, e)
		}
	}
	return result
}

// TouchMRU moves an entry to the top of the MRU list file.
func TouchMRU(path, entry string) {
	os.MkdirAll(pathDir(path), 0755)

	existing := ReadMRU(path)
	result := []string{entry}
	for _, e := range existing {
		if e != entry {
			result = append(result, e)
		}
	}

	os.WriteFile(path, []byte(strings.Join(result, "\n")+"\n"), 0644)
}

// SortByMRU reorders items so that recently used ones appear first.
// Unknown items keep their original order and appear after known ones.
func SortByMRU(path string, items []string) []string {
	mru := ReadMRU(path)
	if len(mru) == 0 {
		return items
	}

	rank := make(map[string]int, len(mru))
	for i, entry := range mru {
		rank[entry] = i
	}

	var known, unknown []string
	for _, item := range items {
		if _, ok := rank[item]; ok {
			known = append(known, item)
		} else {
			unknown = append(unknown, item)
		}
	}

	sort.Slice(known, func(i, j int) bool {
		return rank[known[i]] < rank[known[j]]
	})

	return append(known, unknown...)
}

func pathDir(path string) string {
	for i := len(path) - 1; i >= 0; i-- {
		if path[i] == '/' {
			return path[:i]
		}
	}
	return "."
}
