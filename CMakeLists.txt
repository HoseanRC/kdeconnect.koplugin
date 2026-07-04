cmake_minimum_required(VERSION 3.10)
project(WolfSSLApp C)

set(CMAKE_C_STANDARD 11)

# 1. WolfSSL Library Build Project
# Find all source files
file(GLOB WOLFSSL_SRC RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} CONFIGURE_DEPENDS "wolfssl/src/*.c")
file(GLOB WOLFCRYPT_SRC RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} CONFIGURE_DEPENDS "wolfssl/wolfcrypt/src/*.c")



# List of files to exclude
file(GLOB EXCLUDE_PK RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} CONFIGURE_DEPENDS "wolfssl/src/pk_*.c")
file(GLOB EXCLUDE_SSL RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} CONFIGURE_DEPENDS "wolfssl/src/ssl_*.c")
file(GLOB EXCLUDE_X509 RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} CONFIGURE_DEPENDS "wolfssl/src/x509_*.c")
set(EXCLUDE_FILES
    ${EXCLUDE_PK}
    ${EXCLUDE_SSL}
    ${EXCLUDE_X509}
    "wolfssl/src/pk.c"
    "wolfssl/src/x509.c"
    "wolfssl/src/conf.c"
    "wolfssl/src/bio.c"
    "wolfssl/wolfcrypt/src/misc.c"
    "wolfssl/wolfcrypt/src/evp.c"
    "wolfssl/wolfcrypt/src/asn_orig.c"
    "wolfssl/wolfcrypt/src/evp_pk.c"
)

message(${EXCLUDE_FILES})

# Remove excluded files from the list
list(REMOVE_ITEM WOLFSSL_SRC ${EXCLUDE_FILES})
list(REMOVE_ITEM WOLFCRYPT_SRC ${EXCLUDE_FILES})

# Create the library target
add_library(wolfssl_lib STATIC ${WOLFSSL_SRC} ${WOLFCRYPT_SRC})

# Define Includes and Macros for the library
target_include_directories(wolfssl_lib PUBLIC 
    ${CMAKE_CURRENT_SOURCE_DIR}       # For user_settings.h
    ${CMAKE_CURRENT_SOURCE_DIR}/wolfssl # For wolfssl headers
)

target_compile_definitions(wolfssl_lib PUBLIC WOLFSSL_USER_SETTINGS)

# 2. Application Executable Build Project
add_executable(genkey genkey.c)

# Link the library and inherit configuration
target_link_libraries(genkey PRIVATE wolfssl_lib)

# Ensure the app also uses the same definitions
target_compile_definitions(genkey PRIVATE WOLFSSL_USER_SETTINGS)
target_include_directories(genkey PRIVATE 
    ${CMAKE_CURRENT_SOURCE_DIR} 
    ${CMAKE_CURRENT_SOURCE_DIR}/wolfssl
)