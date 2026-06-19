APP="$HOME/wsjtx-prefix/wsjtx.app"
# oder:
# APP="$HOME/jtdx-prefix/install/jtdx.app"

echo "APP=$APP"
test -d "$APP" || { echo "FEHLT: $APP"; exit 1; }

echo
echo "### 1) Externe absolute Library-Links"
find "$APP" \( -type f -perm -111 -o -name "*.dylib" -o -name "*.so" \) -print0 |
while IFS= read -r -d '' f; do
  otool -L "$f" 2>/dev/null | awk -v file="$f" '
    NR==1 { next }
    {
      lib=$1
      if (lib ~ /^\// &&
          lib !~ "^" ENVIRON["APP"] &&
          lib !~ "^/System/" &&
          lib !~ "^/usr/lib/") {
        print "BAD external: " file " -> " lib
      }
    }'
done | sort -u

echo
echo "### 2) Problematische @rpath-Links"
find "$APP" \( -type f -perm -111 -o -name "*.dylib" -o -name "*.so" \) -print0 |
while IFS= read -r -d '' f; do
  otool -L "$f" 2>/dev/null | awk -v file="$f" '
    NR==1 { next }
    $1 ~ /^@rpath\// {
      print file " -> " $1
    }'
done | sort -u

echo
echo "### 3) RPATHs"
find "$APP" \( -type f -perm -111 -o -name "*.dylib" -o -name "*.so" \) -print0 |
while IFS= read -r -d '' f; do
  otool -l "$f" 2>/dev/null |
  awk -v file="$f" '
    /cmd LC_RPATH/ { inrpath=1 }
    inrpath && /path / {
      print file " -> " $2
      inrpath=0
    }'
done | sort -u

echo
echo "### 4) Symlinks im Bundle"
find "$APP" -type l -print

echo
echo "### 5) Fehlende @executable_path/@loader_path Ziele"
find "$APP" \( -type f -perm -111 -o -name "*.dylib" -o -name "*.so" \) -print0 |
while IFS= read -r -d '' f; do
  dir="$(dirname "$f")"
  exe_dir="$APP/Contents/MacOS"

  otool -L "$f" 2>/dev/null | awk 'NR>1 {print $1}' |
  while read -r dep; do
    case "$dep" in
      @executable_path/*)
        resolved="${dep/@executable_path/$exe_dir}"
        [ -e "$resolved" ] || echo "MISSING: $f -> $dep -> $resolved"
        ;;
      @loader_path/*)
        resolved="${dep/@loader_path/$dir}"
        [ -e "$resolved" ] || echo "MISSING: $f -> $dep -> $resolved"
        ;;
    esac
  done
done | sort -u

echo
echo "### 6) Harte Homebrew/MacPorts/Hamlib-Reste"
find "$APP" \( -type f -perm -111 -o -name "*.dylib" -o -name "*.so" \) -print0 |
while IFS= read -r -d '' f; do
  otool -L "$f" 2>/dev/null | grep -E "/opt/homebrew|/opt/local|/usr/local" && echo "in: $f"
done

echo
echo "### 7) Codesign"
codesign --verify --deep --strict --verbose=4 "$APP"

