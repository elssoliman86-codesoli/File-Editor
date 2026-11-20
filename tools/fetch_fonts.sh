#!/usr/bin/env bash
set -euo pipefail

# The project workspace tool cannot transport binary assets. CI and fresh
# checkouts fetch the exact OFL font files from the official google/fonts repo.
root="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$root/assets/fonts"
base="https://raw.githubusercontent.com/google/fonts/main/ofl"
files=(
  "tajawal/Tajawal-Regular.ttf"
  "tajawal/Tajawal-Medium.ttf"
  "tajawal/Tajawal-Bold.ttf"
  "notonaskharabic/NotoNaskhArabic%5Bwght%5D.ttf"
  "tajawal/OFL.txt"
  "notonaskharabic/OFL.txt"
)
for remote in "${files[@]}"; do
  name="${remote##*/}"
  name="${name//%5B/[}"
  name="${name//%5D/]}"
  if [[ "$name" == "NotoNaskhArabic[wght].ttf" ]]; then
    name="NotoNaskhArabic-Variable.ttf"
  elif [[ "$remote" == "tajawal/OFL.txt" ]]; then
    name="Tajawal-OFL.txt"
  elif [[ "$remote" == "notonaskharabic/OFL.txt" ]]; then
    name="NotoNaskhArabic-OFL.txt"
  fi
  curl --fail --location --retry 3 --silent --show-error \
    "$base/$remote" --output "$root/assets/fonts/$name"
done
printf 'Downloaded %s OFL font/license files.\n' "${#files[@]}"
