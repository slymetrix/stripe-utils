die() {
    echo "$@" >&2
    exit 1
}

check_bin() {
    if ! which "$1" >/dev/null 2>/dev/null; then
        die "'$1' is required, please install it" >&2
    fi
}

check_curl() {
    check_bin curl
}

check_dasel() {
    check_bin dasel
}

STRIPE_BASE_URL="https://api.stripe.com/v1"

stripe_request() {
    local method="$(echo -n "$1" | tr '[:lower:]' '[:upper:]')"
    local path="$2"
    local api_key="$3"
    shift 3

    if [ "$method" = GET ]; then
        set -- "$@" -G
    fi

    local file="$(mktemp)"
    local code ret_code
    code="$(curl -sL -X"$method" --output "${file}" "${STRIPE_BASE_URL}/${path}" -u "${api_key}:" --write-out '%{http_code}' "$@")"
    ret_code=$?

    if [ "$code" = 401 ]; then
        rm -f "$file"
        die "Invalid API Key"
    elif [ "$code" = 400 ]; then
        local msg="$(dasel -f "$file" -s 'error.message' -p json --plain)"
        rm -f "$file"
        die "$msg"
    else
        if [ "$ret_code" = 0 ]; then
            case "$code" in
                2*);;
                *)
                    ret_code=1
                    ;;
            esac
        fi

        cat "$file"
        rm -f "$file"
        return $ret_code
    fi
}

create_promotion_code() {
    local api_key="$1"
    local coupon="$2"
    shift 2
    stripe_request POST promotion_codes "${api_key}" -d"coupon=${coupon}" "$@"
}

list_promotion_codes() {
    stripe_request GET promotion_codes "$@"
}

retry() {
    local code=1

    while [ "$code" != 0 ]; do
        "$@"
        code="$?"
    done
}
