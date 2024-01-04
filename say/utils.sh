convert_country_code() {
    local code="$1"
    local country=""

    case "$code" in
        US) country="United States";;
        GB) country="United Kingdom";;
        FR) country="France";;
        DE) country="Germany";;
        JP) country="Japan";;
        *) country="Unknown";;
    esac

    echo "$country"
}

convert_language_code() {
    local code="$1"
    local language=""

    case "$code" in
        en) language="English";;
        fr) language="French";;
        de) language="German";;
        es) language="Spanish";;
        zh) language="Chinese";;
        *) language="Unknown";;
    esac

    echo "$language"
}
