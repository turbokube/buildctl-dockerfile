package main

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"strings"

	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

type PackageInfo struct {
	Name        string            `json:"name"`
	Version     string            `json:"version"`
	Description string            `json:"description"`
	Bin         map[string]string `json:"bin"`
	Os          []string          `json:"os"`
	Cpu         []string          `json:"cpu"`
}

type TestReport struct {
	Package     string `json:"package"`
	Version     string `json:"version"`
	BinaryPath  string `json:"binary_path"`
	BinarySize  int64  `json:"binary_size"`
	Checksum    string `json:"checksum"`
	Executable  bool   `json:"executable"`
	VersionInfo string `json:"version_info,omitempty"`
	Error       string `json:"error,omitempty"`
}

func main() {
	consoleDebugging := zapcore.Lock(os.Stderr)
	consoleEncoder := zapcore.NewConsoleEncoder(zap.NewDevelopmentEncoderConfig())
	consoleEnabler := zap.LevelEnablerFunc(func(lvl zapcore.Level) bool {
		return true
	})
	core := zapcore.NewCore(consoleEncoder, consoleDebugging, consoleEnabler)
	logger := zap.New(core)
	defer logger.Sync()
	undo := zap.ReplaceGlobals(logger)
	defer undo()

	npm, err := filepath.Abs("../npm")
	if err != nil {
		zap.L().Fatal("get npm dir", zap.Error(err))
	}

	if _, err := os.Stat(npm); os.IsNotExist(err) {
		zap.L().Fatal("npm directory does not exist", zap.String("path", npm))
	}

	var reports []TestReport

	// Read all package directories
	dirs, err := os.ReadDir(npm)
	if err != nil {
		zap.L().Fatal("read npm dir", zap.Error(err))
	}

	for _, dir := range dirs {
		if !dir.IsDir() {
			continue
		}

		pkgDir := path.Join(npm, dir.Name())
		report := testPackage(pkgDir)
		reports = append(reports, report)
	}

	// Output reports as JSON
	output, err := json.MarshalIndent(reports, "", "  ")
	if err != nil {
		zap.L().Fatal("marshal reports", zap.Error(err))
	}

	fmt.Println(string(output))

	// Summary
	fmt.Fprintf(os.Stderr, "\n=== Test Summary ===\n")
	fmt.Fprintf(os.Stderr, "Total packages tested: %d\n", len(reports))
	
	successful := 0
	for _, report := range reports {
		if report.Error == "" && report.Executable {
			successful++
		}
	}
	
	fmt.Fprintf(os.Stderr, "Successful: %d\n", successful)
	fmt.Fprintf(os.Stderr, "Failed: %d\n", len(reports)-successful)

	if successful != len(reports) {
		os.Exit(1)
	}
}

func testPackage(pkgDir string) TestReport {
	report := TestReport{
		Package: filepath.Base(pkgDir),
	}

	// Read package.json
	packageJsonPath := path.Join(pkgDir, "package.json")
	packageData, err := ioutil.ReadFile(packageJsonPath)
	if err != nil {
		report.Error = fmt.Sprintf("read package.json: %v", err)
		return report
	}

	var pkg PackageInfo
	if err := json.Unmarshal(packageData, &pkg); err != nil {
		report.Error = fmt.Sprintf("parse package.json: %v", err)
		return report
	}

	report.Version = pkg.Version

	// Find binary
	if len(pkg.Bin) == 0 {
		report.Error = "no binary specified in package.json"
		return report
	}

	// Get the first (and should be only) binary
	var binPath string
	for _, binRelPath := range pkg.Bin {
		binPath = path.Join(pkgDir, binRelPath)
		break
	}

	report.BinaryPath = binPath

	// Check if binary exists
	stat, err := os.Stat(binPath)
	if err != nil {
		report.Error = fmt.Sprintf("binary not found: %v", err)
		return report
	}

	report.BinarySize = stat.Size()

	// Check if executable
	if stat.Mode()&0111 != 0 {
		report.Executable = true
	}

	// Calculate checksum
	file, err := os.Open(binPath)
	if err != nil {
		report.Error = fmt.Sprintf("open binary for checksum: %v", err)
		return report
	}
	defer file.Close()

	hasher := sha256.New()
	if _, err := io.Copy(hasher, file); err != nil {
		report.Error = fmt.Sprintf("calculate checksum: %v", err)
		return report
	}

	report.Checksum = fmt.Sprintf("sha256:%x", hasher.Sum(nil))

	// Try to get version info from binary
	if report.Executable {
		cmd := exec.Command(binPath, "--version")
		output, err := cmd.Output()
		if err == nil {
			report.VersionInfo = strings.TrimSpace(string(output))
		}
	}

	zap.L().Info("tested package", 
		zap.String("package", report.Package),
		zap.String("version", report.Version),
		zap.Int64("size", report.BinarySize),
		zap.Bool("executable", report.Executable),
		zap.String("checksum", report.Checksum),
	)

	return report
}