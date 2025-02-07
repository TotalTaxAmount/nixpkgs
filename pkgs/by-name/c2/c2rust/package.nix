{
  makeRustPlatform,
  callPackage,
  fetchFromGitHub,
  pkg-config,
  python3,
  cmake,
  libclang,
  tinycbor,
  stdenv,
  glibc,
  lib,
  llvmPackages_14,
}:

let
  rustPlatform = mkRustPlatform {
    date = "2022-08-08"; # https://github.com/immunant/c2rust/blob/master/rust-toolchain.toml
    channel = "nightly";
  };

  mkRustPlatform =
    { date, channel }:
    let
      mozillaOverlay = fetchFromGitHub {
        owner = "mozilla";
        repo = "nixpkgs-mozilla";
        rev = "534ee26d3dbcbb9da3766c556638b9bcc3627871";
        sha256 = "sha256-oh7GSCjBGHpxaU8/gejT55mlvI3qoKObXgqyn1XR7SA=";
      };
      mozilla = callPackage "${mozillaOverlay.out}/package-set.nix" { };
      rustSpecific =
        ((mozilla.rustChannelOf { inherit date channel; }).rust.overrideAttrs (prev: {
          targetPlatforms = lib.platforms.linux;
          badTargetPlatforms = [ ];
        })).override
          {
            extensions = [
              "rustfmt-preview"
              "rustc-dev"
              "rust-src"
              "miri-preview"
            ];
          };
    in
    makeRustPlatform {
      cargo = rustSpecific;
      rustc = rustSpecific;
    };
in

rustPlatform.buildRustPackage rec {
  pname = "c2rust";
  version = "0.19.0";

  src = fetchFromGitHub {
    owner = "immunant";
    repo = "c2rust";
    rev = "v${version}";
    hash = "sha256-WB+8gSr6utEuNzQthBO6ESMZ67AlpM5+1/PQ4VVB1Fc=";
  };

  TINYCBOR_PATH = "${tinycbor}";
  LIBC_INCLUDE_DIR = "${llvmPackages_14.libclang.lib}/lib/clang/${llvmPackages_14.libclang.version}/include";
  LIBCLANG_PATH = "${llvmPackages_14.libclang.lib}/lib";
  LIBCXX_INCLUDE_DIR = "${llvmPackages_14.libcxx.dev}/include";
  GLIBC_INCLUDE_DIR = "${glibc.dev}/include";
  # NIX_CFLAGS_COMPILE = "-I${llvmPackages_14.libcxx.dev}/include/c++/v1 -I${GLIBC_INCLUDE_DIR} -I${LIBC_INCLUDE_DIR} -I${LIBC_INCLUDE_DIR}";

  nativeBuildInputs = [
    llvmPackages_14.libllvm
    llvmPackages_14.llvm
    llvmPackages_14.libcxx
    llvmPackages_14.clang
    llvmPackages_14.libclang
    cmake
    glibc
    tinycbor
    pkg-config
    python3
  ];

  patches = [
    ./00-nix-tinycbor.patch
    ./01-bindgen-fixes.patch
  ];

  cargoLock = {
    lockFile = ./Cargo.lock;
  };

  meta = with lib; {
    platforms = platforms.linux;
  };

}
