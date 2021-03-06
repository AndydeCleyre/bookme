#!/usr/bin/env zsh

bookme () {  # [--procs <number of simultaneous downloads>] [--format epub|pdf|both] [--folder <path>] [<textbooks.csv>]
    emulate -L zsh
    print -u2 'Usage: bookme [--procs <number of simultaneous downloads>] [--format epub|pdf|both] [--folder <path>] [<textbooks.csv>]'
    [[ $1 == --help || $1 == -h ]] && return
    .bookme_requirements || return 1
    trap "cd ${(q-)PWD}" EXIT

    local numprocs format dest
    while [[ $1 == --procs || $1 == --format || $1 == --folder ]]; do
        if [[ $1 == --procs ]]; then numprocs=$2; shift 2; fi
        if [[ $1 == --format ]]; then format=$2; shift 2; fi
        if [[ $1 == --folder ]]; then dest=${2:a}; shift 2; fi
    done
    dest=${dest:-books_$(date +%s)}
    print "Find your goodies at ${dest:a}"
    numprocs=${numprocs:-${${$(nproc 2>/dev/null):-$(sysctl -n hw.logicalcpu 2>/dev/null)}:-4}}
    if [[ ! $format ]]; then
        local choices=(EPUB PDF Both)
        format=${$(
            fzf --reverse --phony --prompt='Choose your preferred book format:' <<<${(F)choices}
        ):l}
    fi
    [[ $format ]] || return 1

    .bookme_choose_books --header "Destination: ${dest:a}" $1 || return 1
    local wishlist=($reply)

    mkdir -p $dest
    cd $dest || return 1

    autoload -Uz zargs
    zargs -P $numprocs -ri___ -- $wishlist -- .bookme_get_book ___ $format
}

.bookme_choose_books () {  # [--header <msg>] [<textbooks.csv>]
    emulate -L zsh
    local header
    if [[ $1 == --header ]]; then header=$2; shift 2; fi
    .bookme_get_books_map $1 || return 1
    local -A books=($reply)
    local choices=(Some All) wishlist=()
    local choice=$(
        fzf --reverse --phony --header="$header" --prompt='Download *all* (>11GB!) or *some* of the textbooks?' <<<${(F)choices}
    )
    if [[ $choice == All ]]; then
        wishlist=(${(v)books})
    elif [[ $choice == Some ]]; then
        local title titles=(${(f)"$(
            fzf --reverse -m -0 --prompt='Choose one (enter) or many (tab). Filter: ' <<<${(Fk)books}
        )"})
        for title in $titles; do
            wishlist+=(${books[$title]})
        done
    fi
    [[ $wishlist ]] || return 1
    reply=($wishlist)
}

.bookme_requirements () {
    emulate -L zsh
    if (( ! $+commands[fzf] )); then
        print -u2 -P '%F{red}%Bfzf%b required but not found%f'
        print -u2 'See https://github.com/junegunn/fzf#installation'
        return 1
    fi
    local need_wget
    if (( ! $+commands[wget] )); then
        need_wget=1
    else
        local outp=$(wget --help 2>/dev/null)
        [[ ${outp%% *} != GNU ]] && need_wget=1
    fi
    if [[ $need_wget ]]; then
        print -u2 -P '%F{red}%BGNU wget%b required but not found%f'
        print -u2 'On macOS? Try installing with homebrew'
        return 1
    fi
}

.bookme_get_books_map () {  # [<textbooks.csv>]
    emulate -L zsh
    local -A books
    .bookme_get_rows $1 || return 1
    local rows=($reply) row cols
    for row in $rows; do
        cols=("${(@s:",":)row[2,-2]}")
        books[${cols[1]}${cols[2]:+ - $cols[2]}]=$cols[6]
    done
    [[ $books ]] || return 1
    reply=(${(kv)books})
}

.bookme_get_typed_book () {  # epub|pdf <book-id>
    emulate -L zsh
    local book_type=$1 book_id=$2 url
    local fname_pre='  Content-Disposition: filename='
    if [[ $book_type == pdf ]]; then
        url="https://link.springer.com/content/pdf/${book_id//\//%2F}.pdf?javascript-disabled=true"
    else
        url="https://link.springer.com/download/epub/${book_id//\//%2F}.epub?javascript-disabled=true"
    fi
    local url_info=(${(f)"$(wget -qS --spider $url 2>&1)"})
    local code=${${(s: :)url_info[1]}[2]}
    if [[ $code != 200 ]]; then
        print -rPn \
            '%F{red}FAILURE%f' \
            "%F{yellow}${book_id}%f" \
            "%F{blue}${book_type:u}%f" \
            "%F{magenta}${code}%f"
        print -r " See https://link.springer.com/book/$book_id"
        return 1
    else
        if wget -q --content-disposition $url; then
            print -rP \
                '%F{green}SUCCESS%f' \
                "%F{yellow}${book_id}%f" \
                "%F{blue}${book_type:u}%f" \
                ${${(M)url_info:#$fname_pre*}#$fname_pre}
        else
            print -rPn \
                '%F{red}FAILURE%f' \
                "%F{yellow}${book_id}%f" \
                "%F{blue}${book_type:u}%f" \
                $? ${${(M)url_info:#$fname_pre*}#$fname_pre}
            print -r " See https://link.springer.com/book/$book_id"
            return 1
        fi
    fi
}

.bookme_get_book () {  # <book-id> [epub|pdf|both]
    emulate -L zsh
    local -A formats=(pdf epub epub pdf)
    if [[ ! $2 || $2 == both ]]; then
        local format
        for format in $formats; do
            .bookme_get_typed_book $format $1 || true
        done
    else
        if ! .bookme_get_typed_book $2 $1; then
            .bookme_get_typed_book $formats[$2] $1 || true
        fi
    fi
}

.bookme_get_rows () {  # [<textbooks.csv>]
    emulate -L zsh
    local csv=${1:a}
    local download_covid='Download the Covid 19 list to "covid19_textbooks.csv"'
    local download_openaccess='Download the Open Access list to "openacess_textbooks.csv"'
    if [[ ! $csv ]]; then
        local choices=($download_covid $download_openaccess *csv(N:a) 'Quit')
        local choice=$(
            fzf --reverse --phony --prompt='No textbooks.csv specified. What should we use?' <<<${(F)choices}
        )
        [[ $choice == Quit || ! $choice ]] && return 1
        if [[ $choice == $download_covid ]]; then
            wget -nc -O covid19_textbooks.csv \
                'https://link.springer.com/search/csv?facet-content-type=%22Book%22&package=mat-covid19_textbooks' \
                || return 1
            csv=covid19_textbooks.csv
        elif [[ $choice == $download_openaccess ]]; then
            wget -nc -O openaccess_textbooks.csv \
                'https://link.springer.com/search/csv?facet-content-type=%22Book%22&package=openaccess' \
                || return 1
            csv=openaccess_textbooks.csv
        else
            csv=${choice:a}
        fi
    fi
    reply=(${(f)"$(tail -n +2 $csv)"})
}

bookme $@
