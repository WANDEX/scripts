#!/bin/sh
# download via youtube-dl video playlist or single video

# read into variable using 'Here Document' code block
read -d '' USAGE <<- EOF
Usage: $(basename $BASH_SOURCE) [OPTION...]
OPTIONS
    -e, --end           If url is playlist - how many items to download (default:1)
    -h, --help          Display help
    -i, --interactive   Explicit interactive playlist end mode
    -p, --path          Destination path where to download
    -q, --quality       Quality of video/stream
    -r, --restrict      Restrict filenames to only ASCII characters, and avoid "&" and spaces in filenames
    -u, --url           URL of video/stream
EOF

get_opt() {
    # Parse and read OPTIONS command-line options
    SHORT=e:hip:rq:u:
    LONG=end:,help,interactive,path:,restrict,quality:,url:
    OPTIONS=$(getopt --options $SHORT --long $LONG --name "$0" -- "$@")
    # PLACE FOR OPTION DEFAULTS
    OUT="$HOME"'/Films/.yt/'
    END=1      # youtube-dl --playlist-end > get first N items from playlist
    ENDOPT=0
    EXT='webm' # prefer certain extension over FALLBACK in youtube-dl
    QLT='1080' # video height cap, will be less if unavailable in youtube-dl
    URL="$(xclip -selection clipboard -out)"
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
        -i|--interactive)
            [ "$ENDOPT" -eq 1 ] && ENDOPT=0 || ENDOPT=1 # toggle behavior of value
            ;;
        -p|--path)
            shift
            OUT="$1"
            ;;
        -r|--restrict)
            restr=( --restrict-filenames )
            ;;
        -q|--quality)
            shift
            QLT="$1"
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

ytdl_check() {
    # youtube-dl URL verification, verify only first item if many
    JSON="$(youtube-dl --dump-json --no-warnings --playlist-end=1 "$1")"
    return_code=$?
    if [ "$return_code" -ne 0 ]; then
        summary="youtube-dl ERROR CODE[$return_code]:"
        msg="TERMINATED\nInvalid URL,\nor just the first element from the URL"
        notify-send -t 5000 -u critical "$summary" "$msg"
        exit $return_code
    else
        RAWOUT=$(echo "$JSON" | ytdl_out_path.sh)
        OUT="$OUT""$RAWOUT"
    fi
}

ytdl() {
    # youtube-dl
    case "$QLT" in
        *"1"*)
            QLT="1080"
        ;;
        *"4"*)
            QLT="480"
        ;;
        *"7"*)
            QLT="720"
        ;;
        *"8"*)
            QLT="1080"
        ;;
        *)
            QLT="$QLT"
        ;;
    esac >/dev/null
    VIDEO='bestvideo[ext='"$EXT"'][height<=?'"$QLT"']'
    AUDIO='bestaudio[ext='"$EXT"']'
    GLUED="$VIDEO"'+'"$AUDIO"
    FALLBACKVIDEO='bestvideo[height<=?'"$QLT"']'
    FALLBACKAUDIO='bestaudio/best'
    FORMAT="$GLUED"'/'"$FALLBACKVIDEO"'+'"$FALLBACKAUDIO"
    youtube-dl --ignore-errors --yes-playlist --playlist-end="$END" \
        --write-sub --sub-lang en,ru --sub-format "ass/srt/best" --embed-subs \
        --format "$FORMAT" --output "$OUT" "${restr[@]}" "$URL" && \
        notify-send -u normal -t 8000 "COMPLETED:" "Downloading and Converting. [VIDEO]" || \
        notify-send -u critical -t 5000 "ERROR:" "Something gone wrong! [VIDEO]"
}

main() {
    ytdl_check "$URL"
    if [ "$ENDOPT" -eq 1 ]; then
        Q="Download all videos [y/n]? "
        while true; do
            read -p "$Q" -n 1 -r
            echo "" # move to a new line
            case "$REPLY" in
                [Yy]*) END=-1; break;;
                [Nn]*) END=1; break;;
                *) echo "I don't get it.";;
            esac
        done
    fi
    ytdl "$@"
}

main "$@"
