#!/bin/bash
# Download in Music dir audio only stream and convert to audio file format

MUSIC="$HOME/Music/1337"
PODCAST="$MUSIC/podcasts"
YTM="$MUSIC/YTM"

USAGE=$(printf "%s" "\
Usage: $(basename "$0") [OPTION...]
OPTIONS
    -e, --end       If url is playlist - how many items to download (by default all:-1)
    -h, --help      Display help
    -p, --path      Destination path where to download
    -r, --restrict  Restrict filenames to only ASCII characters, and avoid '&' and spaces in filenames
    -u, --url       URL to download
    -y, --ytdl      Any other youtube-dl native options (specify only inside \"\")
EXAMPLES:
    $(basename "$0") -u \"\$URL\" -y '--simulate --get-duration' -y '--playlist-items 1-3'
")

at_path() { hash "$1" >/dev/null 2>&1 ;} # if $1 is found at $PATH -> return 0

find_filepath() {
    # find & return full path of the file by $1 filename
    [ -z "$1" ] && echo "${RED}no filename provided, exit.${END}" && exit 4
    if at_path fd; then
        # use fd to find file (instead of slow 'find')
        _filepath="$(fd --search-path "$MUSIC" -F1t f "$1")"
    else
        _filepath="$(find "$MUSIC" -type f -name "$1" | head -n1)"
    fi
    realpath -q "$_filepath"
}

notify() {
    # use dunstify if available & show notification
    case "$1" in
        *error*|*ERROR*) urg="critical" ;;
        *warning*|*WARNING*) urg="normal" ;;
        *completed*|*COMPLETED*) urg="normal" ;;
        *) urg="low" ;;
    esac
    if at_path dunstify; then
        DSTT="string:x-dunst-stack-tag:[download_audio.sh]($first_file)"
        dunstify -u "$urg" -h "$DSTT" "D[AUDIO] $1" "\n$2\n"
    else
        notify-send -u "$urg" "D[AUDIO] $1" "\n$2\n"
    fi
}

get_opt() {
    # Parse and read OPTIONS command-line options
    SHORT=e:hp:ru:y:
    LONG=end:,help,path:,restrict,url:,ytdl:
    OPTIONS=$(getopt --options $SHORT --long $LONG --name "$0" -- "$@")
    # PLACE FOR OPTION DEFAULTS
    URL="$(xclip -selection clipboard -out)"
    END=-1
    restr=()
    YTDLOPTS=()
    eval set -- "$OPTIONS"
    while true; do
        case "$1" in
        -e|--end)
            shift
            case $1 in
                -1) END=-1 ;; # get full playlist
                0*)
                    printf "(%s)\n^ unsupported number! exit.\n" "$1"
                    exit 1
                    ;;
                ''|*[!0-9]*)
                    printf "(%s)\n^ IS NOT A NUMBER OF INT! exit.\n" "$1"
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
        -y|--ytdl)
            shift
            # convert spaces in argument into individual args if any
            # -> so here we split arg string "$1" to array and arguments
            IFS=' ' read -ra yargs <<< "$1"
            # + to join all previously specified -y options into one array as in EXAMPLES
            YTDLOPTS+=( "${yargs[@]}" )
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
        PD="$MUSIC/bandcamp/"
        OUT="$PD"'%(artist)s/%(playlist)s/%(playlist_index)02d. %(title)s.%(ext)s'
        OPT=( --embed-thumbnail )
    ;;
    *"soundcloud"*"/sets/"*|*"soundcloud"*"/albums"*)
        PD="$MUSIC/soundcloud/"
        OUT="$PD"'%(uploader)s/%(playlist)s/%(playlist_index)02d. %(fulltitle)s.%(ext)s'
        OPT=( --embed-thumbnail )
    ;;
    *"soundcloud"*)
        PD="$MUSIC/soundcloud/"
        OUT="$PD"'%(uploader)s/%(playlist)s/%(fulltitle)s.%(ext)s'
        OPT=( --embed-thumbnail )
    ;;
    *"youtu"*"playlist"*)
        PD="$MUSIC/youtube/"
        OUT="$PD"'%(playlist_title)s/%(playlist_index)02d. %(title)s.%(ext)s'
        OPT=()
    ;;
    *"youtu"*)
        PD="$MUSIC/youtube/"
        OUT="$PD"'%(title)s.%(ext)s'
        OPT=()
    ;;
    *)
        PD="$MUSIC/other/"
        OUT="$PD"'%(title)s.%(ext)s'
        OPT=()
    ;;
esac >/dev/null

# substring
case "$path" in
    "kdi"|"Kdi"|"KDI")
        PD="$PODCAST/KDI/"
        OUT="$PD"'%(title)s.%(ext)s'
        OPT=( --no-playlist )
    ;;
    "koda"|"Koda")
        PD="$PODCAST/Koda-Koda/"
        OUT="$PD"'%(title)s.%(ext)s'
        OPT=( --no-playlist )
    ;;
    "lt"|"launch")
        PD="$PODCAST/Launch Tomorrow Podcast/"
        OUT="$PD"'%(title)s.%(ext)s'
        OPT=( --no-playlist )
    ;;
    "podcast"|"Podcast")
        PD="$PODCAST/"
        OUT="$PD"'%(title)s.%(ext)s'
        OPT=( --no-playlist )
    ;;
    "ytm"|"Ytm"|"YTM")
        PD="$YTM/RNDM/"
        OUT="$PD"'%(uploader)s/%(title)s.%(ext)s'
        OPT=( --no-playlist )
    ;;
    *)
        if [ -n "$path" ]; then
            # add/replace 0 or more occurrences of '/' at the end, with one /
            PD="$(echo "$path" | sed "s/[/]*$/\//")"
            OUT="$PD"'%(title)s.%(ext)s'
            OPT=( --no-playlist )
        fi
    ;;
esac >/dev/null

BEST="bestaudio[asr=48000]"
FALLBACK="bestaudio/best"
FORMAT="${BEST}/${FALLBACK}"

cmd=(\
youtube-dl --ignore-errors --yes-playlist --playlist-end="$END" \
--format "$FORMAT" --output "$OUT" \
--extract-audio --audio-format "mp3" \
--add-metadata --no-overwrites --no-post-overwrites \
--youtube-skip-dash-manifest \
"${restr[@]}" "${OPT[@]}" "${YTDLOPTS[@]}" \
)

# try to get url info as json & check exit code
if json="$("${cmd[@]}" --dump-json "$URL")"; then
    # get list of all files from url and replace any .extension on .mp3
    # (because we convert everything to mp3 after downloading)
    list_files="$(echo "$json" | jq -er '._filename' | sed "s/\.[^.]*$/\.mp3/g")"
    first_file="$(echo "$list_files" | head -n1)"
    if [ -z "$first_file" ]; then
        notify "ERROR" "[EXIT] No _filename in json data.\n$URL"
        exit 3
    fi
else
    notify "ERROR" "[EXIT] Cannot get url info.\n$URL"
    exit 2
fi

notify "STARTED path:" "$OUT"

# try to download & check exit code
if "${cmd[@]}" "$URL"; then
    notify "COMPLETED" "$PD"
else
    notify "ERROR" "[EXIT] CANNOT DOWNLOAD!\n$URL"
    exit 1
fi

if [ -f "$first_file" ]; then
    filepath="$(realpath -q "$first_file")"
else
    # TODO: UNTESTED -> MAYBE NOT CORRECT!
    filepath="$(find_filepath "$first_file")"
    notify "WARNING: FIND FILE PATH FUNC IS USED!" "first file:$first_file" # XXX
fi

if [ -n "$filepath" ]; then
    # remove from tags: all-comments, user-text-frames:(comment, description)
    if at_path eyeD3; then
        eyeD3 --preserve-file-times --remove-all-comments \
            --user-text-frame "comment:" --user-text-frame "description:" "$filepath"
    fi
fi


