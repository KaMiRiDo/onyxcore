# Master Prompt: Regression Test Framework Initialization

**Role:** Act as a Senior Flutter SDET (Software Development Engineer in Test) and Systems Architect. 

**Context:** We are building a blazing-fast, strictly sandboxed regression test framework for a local desktop File Manager application. To guarantee 100% safety (avoiding accidental data loss or mutations on the host OS), we use a strict Dependency Injection architecture. We use the `file` package to abstract `dart:io`. The production app utilizes `LocalFileSystem`, but our Unit and Widget test suites will exclusively run on `MemoryFileSystem`.

**Objective:** Set up the foundational test infrastructure, scalable directory structure, dependency injection layer, and reusable helper classes. 

**STRICT CONSTRAINTS (CRITICAL):**
1. **NO TEST CASES:** DO NOT write specific test cases (`test()` or `testWidgets()` bodies) for features, UI, or edge cases yet. I will provide those scenarios in subsequent prompts.
2. **INFRASTRUCTURE ONLY:** Only write the boilerplate, architecture, and structural code required to support future tests.
3. **ABSOLUTE ISOLATION:** Completely decouple `dart:io` from the app's core file access logic. No direct `File()` or `Directory()` calls from `dart:io` are allowed in the service layer.

**EXECUTE THE FOLLOWING TASKS IN ORDER:**

### 1. Dependencies Setup
Provide the exact YAML snippets to update `pubspec.yaml`. 
- Ensure `file: ^7.0.0` (or latest) is in dependencies. 
- Ensure `flutter_test` and `mocktail` (for future non-file mocking) are in `dev_dependencies`.

### 2. Abstraction Layer (`lib/services/file_system_service.dart`)
Create the core `FileSystemService`. 
- It must accept a `FileSystem` object via its constructor. 
- It should default to `const LocalFileSystem()` if no argument is passed (allowing for seamless production use and easy test injection).
- Include 1-2 basic wrapper methods (e.g., `Directory getDirectory(String path)`) to demonstrate usage.

### 3. Test Directory Structure
Define a clean, scalable hierarchy for the `test/` folder. Briefly explain the purpose of each:
- `test/unit/` (Data/Service layer)
- `test/widgets/` (UI component tests)
- `test/helpers/` (Test utilities)
- `test/mocks/` (Mocktail definitions)

### 4. Reusable Helpers (`test/helpers/file_system_helper.dart`)
Create a robust utility class for our test setups.
- Create a function (e.g., `MemoryFileSystem setupMockFileSystem()`) that initializes a `MemoryFileSystem`.
- Automatically populate it with a dummy directory tree (e.g., a fake `/Home` folder, `/Downloads` folder, and a few mock `.txt` and `.png` files). This will be heavily reused in our `setUp()` blocks.

### 5. Skeleton Boilerplate Injection
Create two skeleton test files to prove the Dependency Injection works. 
- **File 1:** `test/unit/file_system_service_test.dart`
- **File 2:** `test/widgets/directory_view_test.dart`
- In both files, write the `main()` function and the `setUp()` block where the `MemoryFileSystem` (using the helper from Task 4) is initialized and injected into the target service/widget. 
- Leave the actual `test()` and `testWidgets()` blocks completely empty with a single comment: `// TODO: Test cases will be provided by user.`

**Confirmation:** Once you have provided the complete code for these 5 tasks, pause and ask me to provide the first batch of specific test scenarios.