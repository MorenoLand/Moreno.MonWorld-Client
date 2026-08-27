package main

import (
	"archive/zip"
	"crypto/sha1"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

const verifiedFireRedRev1SHA1 = "dd5945db9b930750cb39d00c84da8571feebf417"

type manifest struct {
	SchemaVersion int       `json:"schema_version"`
	ContentID     string    `json:"content_id"`
	Source        source    `json:"source"`
	Maps          []mapInfo `json:"maps"`
}

type source struct {
	Game     string `json:"game"`
	Revision string `json:"revision"`
	ROMSHA1  string `json:"rom_sha1"`
}

type mapInfo struct {
	ID     string `json:"id"`
	Name   string `json:"name"`
	Width  int    `json:"width"`
	Height int    `json:"height"`
}

func main() {
	romPath := flag.String("rom", "", "path to a user-owned FireRed Rev1 ROM dump")
	outputPath := flag.String("output", "monworld-firered-rev1.monpack", "external .monpack output path")
	flag.Parse()
	if strings.TrimSpace(*romPath) == "" {
		fail(errors.New("-rom is required"))
	}
	if err := importROM(*romPath, *outputPath); err != nil {
		fail(err)
	}
	fmt.Printf("created external content pack: %s\n", *outputPath)
}

func importROM(romPath, outputPath string) error {
	romHash, err := hashFile(romPath)
	if err != nil {
		return err
	}
	if romHash != verifiedFireRedRev1SHA1 {
		return fmt.Errorf("unsupported ROM SHA-1 %s; expected verified FireRed Rev1 %s; patched or unknown ROMs are rejected", romHash, verifiedFireRedRev1SHA1)
	}
	pack := manifest{SchemaVersion: 1, ContentID: "firered-rev1-kanto-slice-v1", Source: source{Game: "FireRed", Revision: "Rev1", ROMSHA1: verifiedFireRedRev1SHA1}, Maps: []mapInfo{{ID: "pallet-town", Name: "Pallet Town", Width: 20, Height: 18}, {ID: "route-1", Name: "Route 1", Width: 30, Height: 40}, {ID: "viridian-city", Name: "Viridian City", Width: 30, Height: 25}}}
	if err := os.MkdirAll(filepath.Dir(outputPath), 0o700); err != nil {
		return fmt.Errorf("create output directory: %w", err)
	}
	file, err := os.Create(outputPath)
	if err != nil {
		return fmt.Errorf("create content pack: %w", err)
	}
	defer file.Close()
	archive := zip.NewWriter(file)
	data, err := json.MarshalIndent(pack, "", "  ")
	if err != nil {
		return fmt.Errorf("encode content manifest: %w", err)
	}
	entry, err := archive.Create("manifest.json")
	if err != nil {
		return fmt.Errorf("create manifest entry: %w", err)
	}
	if _, err := entry.Write(append(data, '\n')); err != nil {
		return fmt.Errorf("write content manifest: %w", err)
	}
	metadata, err := archive.Create("README.txt")
	if err != nil {
		return fmt.Errorf("create pack metadata entry: %w", err)
	}
	if _, err := io.WriteString(metadata, "This external pack contains only original project metadata and generated placeholders. Keep it outside source control.\n"); err != nil {
		return fmt.Errorf("write pack metadata: %w", err)
	}
	if err := archive.Close(); err != nil {
		return fmt.Errorf("close content pack: %w", err)
	}
	return nil
}

func hashFile(path string) (string, error) {
	file, err := os.Open(path)
	if err != nil {
		return "", fmt.Errorf("open ROM: %w", err)
	}
	defer file.Close()
	hash := sha1.New()
	if _, err := io.Copy(hash, file); err != nil {
		return "", fmt.Errorf("hash ROM: %w", err)
	}
	return hex.EncodeToString(hash.Sum(nil)), nil
}

func fail(err error) {
	fmt.Fprintln(os.Stderr, err)
	os.Exit(1)
}
