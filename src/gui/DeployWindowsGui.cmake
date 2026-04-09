if (NOT WIN32)
    return()
endif()

if (NOT DEFINED TARGET_FILE OR NOT EXISTS "${TARGET_FILE}")
    message(FATAL_ERROR "TARGET_FILE is missing for GUI deployment")
endif()

if (NOT DEFINED OUTPUT_DIR OR NOT IS_DIRECTORY "${OUTPUT_DIR}")
    message(FATAL_ERROR "OUTPUT_DIR is missing for GUI deployment")
endif()

if (DEFINED WINDEPLOYQT_EXECUTABLE AND EXISTS "${WINDEPLOYQT_EXECUTABLE}")
    execute_process(
        COMMAND "${WINDEPLOYQT_EXECUTABLE}"
            --release
            --no-translations
            --no-system-d3d-compiler
            --no-opengl-sw
            "${TARGET_FILE}"
        RESULT_VARIABLE deploy_result
    )
    if (NOT deploy_result EQUAL 0)
        message(FATAL_ERROR "windeployqt failed with exit code ${deploy_result}")
    endif()
else()
    message(WARNING "windeployqt was not found; skipping Qt runtime deployment")
endif()

if (DEFINED OPENSSL_ROOT_HINT AND OPENSSL_ROOT_HINT)
    set(OPENSSL_BIN_DIR "${OPENSSL_ROOT_HINT}/bin")
endif()

foreach(ssl_dll IN ITEMS libssl-3-x64.dll libcrypto-3-x64.dll)
    if (DEFINED OPENSSL_BIN_DIR AND EXISTS "${OPENSSL_BIN_DIR}/${ssl_dll}")
        file(COPY "${OPENSSL_BIN_DIR}/${ssl_dll}" DESTINATION "${OUTPUT_DIR}")
    else()
        message(FATAL_ERROR "Required OpenSSL runtime not found: ${ssl_dll}")
    endif()
endforeach()

set(ZLIB_DEST "${OUTPUT_DIR}/zlib.dll")
if (NOT EXISTS "${ZLIB_DEST}")
    set(zlib_search_script [=[
$roots = @()
if ($env:ProgramFiles) { $roots += $env:ProgramFiles }
if ($env:'ProgramFiles(x86)') { $roots += $env:'ProgramFiles(x86)' }
$candidates = foreach ($root in $roots) {
    Get-ChildItem -Path $root -Filter zlib.dll -Recurse -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName
}
$preferred = $candidates | Where-Object {
    $_ -like '*MySQL Workbench*' -or $_ -like '*Nsight*'
} | Select-Object -First 1
if (-not $preferred) {
    $preferred = $candidates | Select-Object -First 1
}
if ($preferred) {
    [Console]::Out.Write($preferred)
}
]=])

    execute_process(
        COMMAND powershell -NoProfile -ExecutionPolicy Bypass -Command "${zlib_search_script}"
        OUTPUT_VARIABLE zlib_source
        OUTPUT_STRIP_TRAILING_WHITESPACE
        RESULT_VARIABLE zlib_search_result
    )

    if (zlib_search_result EQUAL 0 AND EXISTS "${zlib_source}")
        file(COPY "${zlib_source}" DESTINATION "${OUTPUT_DIR}")
    else()
        message(FATAL_ERROR "zlib.dll was not found; barrier.exe would miss a Qt5Network dependency")
    endif()
endif()

foreach(legacy_dll IN ITEMS libssl-1_1-x64.dll libcrypto-1_1-x64.dll)
    if (EXISTS "${OUTPUT_DIR}/${legacy_dll}")
        file(REMOVE "${OUTPUT_DIR}/${legacy_dll}")
    endif()
endforeach()
