#!/bin/sh
# Download in Music dir audio only stream and convert to audio file format

MUSIC="$HOME"'/Music/'
PODCAST="$MUSIC"'podcasts/'
YTM="$MUSIC"'~YTM/'

# read into variable using 'Here Document' code block
read -d '' USAGE <<- EOF
Usage: $(basename $BASH_SOURCE) [OPTION...]
OPTIONS
    -e, --end       If url is playlist - how many items to download (by default all:-1)
    -h, --help      Display help
    -p, --path      Destination path where to download
    -r, --restrict  Restrict filenames to only ASCII characters, and avoid "&" and spaces in filenames
    -u, --url       URL to download
EOF

get_opt() {
    # Parse and read OPTIONS command-line options
    SHORT=e:hp:ru:
    LONG=end:,help,path:,restrict,url:
    OPTIONS=$(getopt --options $SHORT --long $LONG --name "$0" -- "$@")
    # PLACE FOR OPTION DEFAULTS
    URL="$(xclip -selection clipboard -out)"
    END=-1
    restr=()
    eval set -- "$OPTIONS"
    while true; do
        case "$1" in
        -e|--end)
            shift
            case $1 in
                -1) END=-1 ;; # get full playlist
                0*)
                    printf "($1)\n^ unsupported number! exit.\n"
                    exit 1
                    ;;
                ''|*[!0-9]*)
                    printf "($1)\n^ IS NOT A NUMBER OF INT! exit.\n"
                    exit 1
                    ;;
                *) END=$1 ;;
            esac
            ;;
        -h|--help)
            echo "$USAGE"
            exit 0
            ;;
        -p|--path)
            shift
            path="$1"
            ;;
        -r|--restrict)
            restr=( --restrict-filenames )
            ;;
        -u|--url)
            shift
            URL="$1"
            ;;
        --)
            shift
            break
            ;;
        esac
        shift
    done
}

get_opt "$@"

# substring
case "$URL" in
    *"bandcamp"*)
        OUT="$MUSIC"'~bandcamp/%(artist)s/%(playlist)s/%(playlist_index)02d. %(title)s.%(ext)s'
        OPT=( --embed-thumbnail )
    ;;
    *"soundcloud"*"/sets/"*|*"soundcloud"*"/albums"*)
        OUT="$MUSIC"'~soundcloud/%(uploader)s/%(playlist)s/%(playlist_index)02d. %(fulltitle)s.%(ext)s'
        OPT=( --embed-thumbnail )
    ;;
    *"soundcloud"*)
        OUT="$MUSIC"'~soundcloud/%(uploader)s/%(playlist)s/%(fulltitle)s.%(ext)s'
        OPT=( --embed-thumbnail )
    ;;
    *"youtu"*"playlist"*)
        OUT="$MUSIC"'~youtube/%(playlist_title)s/%(playlist_index)02d. %(title)s.%(ext)s'
        OPT=()
    ;;
    *"youtu"*)
        OUT="$MUSIC"'~youtube/%(title)s.%(ext)s'
        OPT=()
    ;;
    *)
        OUT="$MUSIC"'~other/%(title)s.%(ext)s'
        OPT=()
    ;;
esac >/dev/null

# substring
case "$path" in
    "kdi"|"Kdi"|"KDI")
        _kdi="$PODCAST"'KDI/'
        OUT="$_kdi"'%(title)s.%(ext)s'
        OPT=( --no-playlist )
    ;;
    "koda"|"Koda")
        _koda="$PODCAST"'Koda-Koda/'
        OUT="$_koda"'%(title)s.%(ext)s'
        OPT=( --no-playlist )
    ;;
    "lt"|"launch")
        _lt="$PODCAST"'Launch Tomorrow Podcast/'
        OUT="$_lt"'%(title)s.%(ext)s'
        OPT=( --no-playlist )
    ;;
    "podcast"|"Podcast")
        OUT="$PODCAST"'%(title)s.%(ext)s'
        OPT=( --no-playlist )
    ;;
    "ytm"|"Ytm"|"YTM")
        _ytm="$YTM"'RNDM/%(uploader)s/'
        OUT="$_ytm"'%(title)s.%(ext)s'
        OPT=( --no-playlist )
    ;;
    *)
        if [ ! -z "$path" ]; then
            # add/replace 0 or more occurrences of '/' at the end, with one /
            _path=$(echo "$path" | sed "s/[/]*$/\//")
            OUT="$_path"'%(title)s.%(ext)s'
            OPT=( --no-playlist )
        fi
    ;;
esac >/dev/null

BEST='bestaudio[asr=48000]'
FALLBACK='bestaudio/best'
FORMAT="$BEST"'/'"$FALLBACK"
notify-send -t 3000 "Downloading [AUDIO]... path:" "$OUT"
youtube-dl --ignore-errors --yes-playlist --playlist-end="$END" \
    --format "$FORMAT" --output "$OUT" "${restr[@]}" \
    --extract-audio --audio-format "mp3" "${OPT[@]}" "$URL" && \
    notify-send -u normal -t 8000 "COMPLETED" "[AUDIO] Downloading and Converting." || \
    notify-send -u critical -t 5000 "ERROR" "[AUDIO] Something gone wrong!"

if [[ $_lt ]]; then
    cd "$_lt"
    match=$(find . -maxdepth 1 -not -regex '\./S..E...*\.mp3' -not -name "*.jpg" -not -name "\." | sed 's,\.\/,,')
    new_name=$(echo "$match" | sed 's/\(.*\) \(S..E..\)/\2 - \1/')
    mv -f "$match" "$new_name"
    echo -e "downloaded file renamed:\n$match\t:old\n$new_name\t:new"
fi

