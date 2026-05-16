# OnyxCore Regression Test Guidelines

This manifesto outlines the standard operating procedures, architectural boundaries, and structural formats for generating Test Design Documents and writing test code for the OnyxCore project. All AI coding agents and developers must adhere strictly to these rules across all modules.

## 1. Structural & Naming Conventions

To maintain a scalable and organized repository, the testing architecture must strictly mirror the production codebase.

* **Directory Mirroring:** The directory structure inside `test/` and `_artifacts/test_docs/` must exactly mirror the structure of `lib/`. 
* *Example:* If a file exists at `lib/features/module_name/domain/entity.dart`, its test must live at `test/unit/features/module_name/domain/entity_test.dart` and its documentation at `_artifacts/test_docs/features/module_name/domain/entity_test_doc.md`.
* **File Naming:** * Test Code: `<original_filename>_test.dart`
* Test Documentation: `<original_filename>_test_doc.md`

## 2. Core Testing Philosophy & Isolation

OnyxCore requires a blazing-fast, 100% host-isolated regression suite to prevent data loss and ensure CI/CD stability.

* **Host OS Isolation:** Tests must never interact with the real hard drive. All file I/O operations must be abstracted through the `file` package. Test suites will exclusively inject and use `MemoryFileSystem`.
* **Dependency Injection (DI):** All services, repositories, and state managers (e.g., Riverpod providers) must be constructed via dependency injection to allow for seamless mock replacement during widget testing.
* **Targeted Mocking (`mocktail`):** Use `mocktail` strictly for heavy dependencies (e.g., Repositories, external APIs, native platform controllers). Do not mock simple data models, pure utility functions, or lightweight state objects.

## 3. Test Case Creation & Edge Cases

Test documents must outline a comprehensive suite of scenarios . It should cover the core logic with all edge cases in unit test and even the minute UI beahaviour, styling, shading, shortcuts, navigation and all in widget test .

* **Atomic Independence:** Every test document must be entirely self-contained. A developer should be able to execute the "Given" setup without needing to reference external documentation.
* **Coverage Requirements (90%+ Target):**
* **Happy Paths:** Standard expected behavior and data flow.
* **Edge Cases:** Empty lists, null inputs, boundary values, zero-state UI renders.
* **Error Handling:** Explicit testing of `try-catch` blocks, particularly simulating `FileSystemException`, permission denials, and malformed JSON/data parsing.
* **No Line Numbers:** Never use exact line numbers in documentation. Always target specific methods, variables, or UI interaction blocks by name.


## 4. Test Document Templates

Every `<filename>_test_doc.md` must utilize the following table structures. If a layer does not apply to the specific file (e.g., pure logic has no widgets), mark the table with "N/A - Pure [Layer] Logic".

### 1. Unit Test Plan Format
| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-[MOD]-01 | | | | | | |

### 2. Widget Test Plan Format
| Test ID | File(s) Under Test | Target Widget / State | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-[MOD]-01 | | | | | | |