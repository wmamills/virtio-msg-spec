#!/bin/bash

PREFIX="PATCH v2"
SUBJECT="virtio-msg transport layer"
ME="$(git config --get user.name) <$(git config --get user.email)>"
ME2="Mr Fake <wm.a.mills+mrfake@gmail.com>"
REAL=virtio-comment@lists.linux.dev
US=virtio-msg@lists.linaro.org
CC="Bertrand Marquis <bertrand.marquis@arm.com>,
Edgar E. Iglesias <edgar.iglesias@amd.com>,
Arnaud Pouliquen <arnaud.pouliquen@foss.st.com>,
Viresh Kumar <viresh.kumar@linaro.org>,
Alex Bennee <alex.bennee@linaro.org>,
Armelle Laine <armellel@google.com>"

UPSTREAM_BRANCH=master
BRANCH=$(git rev-parse --abbrev-ref HEAD)
IGNORE_TOP=2
IGNORE_BOTTOM=7     # only used if <branch>-patch-base does not exist

MY_DIR=$(dirname $0)
BASE_DIR=$(cd $MY_DIR/../..; pwd)

get_tag() {
    git show-ref --tag --hash $1 2>/dev/null
}

BASE=$(get_tag ${BRANCH}-merge-base)
if [ -z "${BASE}" ]; then
    BASE=$(git merge-base ${UPSTREAM_BRANCH} HEAD)
fi
if [ -z "${BASE}" ]; then
    echo "Can't find base commit (common ancestor)" >&2
    exit 3
fi

SINCE=$(get_tag ${BRANCH}-patch-base)
if [ -z "${SINCE}" ]; then
    SINCE=$(git log --format=%H ${BASE}..HEAD | tac | head -n $(( $IGNORE_BOTTOM + 0 )) | tail -n 1 )
fi
if [ -z "${SINCE}" ]; then
    echo "Can't find patch base commit (first included commit)" >&2
    exit 3
fi

TOP=$(git log -n 1 --format=%H HEAD~${IGNORE_TOP})
if [ -z "${TOP}" ]; then
    echo "Can't top commit (last included commit)" >&2
    exit 3
fi

if false; then
    echo "BASE:  $(git log -n 1 --oneline $BASE)"
    echo "SINCE: $(git log -n 1 --oneline $SINCE)"
    echo "TOP:   $(git log -n 1 --oneline $TOP)"
    echo "HEAD:  $(git log -n 1 --oneline HEAD)"
fi

echo "Ignore top commits:"
git -P log --oneline ${TOP}..HEAD
echo
echo "Include commits:"
git -P log --oneline ${SINCE}..${TOP}
echo
echo "Ignore bottom commits:"
git -P log --oneline ${BASE}..${SINCE}
echo

echo "^c to cancel, enter to proceed"
read

# example commands
# git log -n 1 --oneline --no-abbrev-commit virtio-msg-patch2-patch-basey
# git log --oneline --no-abbrev-commit a1883517ee44cc03d1b621a331d24a6f5cc08a92..HEAD | tac | head -n $(( 5 + 1 )) | tail -n 1

case $1 in
--for-real)
    TO="$REAL"
    ;;
--just-us)
    TO="$US"
    EXTRA_SEND_OPTS="--no-signed-off-by-cc --suppress-cc=author"
    ;;
--just-me)
    TO="$ME"
    CC="$ME2"
    EXTRA_SEND_OPTS="--no-signed-off-by-cc --suppress-cc=author"
    ;;
--dry-run)
    TO="$ME"
    EXTRA_SEND_OPTS="--dry-run"
    ;;
*)
    echo "Need --for-real, --just-us, or --just-me"; exit 2
    ;;
esac

rm -rf "$BASE_DIR"/.prjinfo/sendmail/patches

git format-patch -o "$BASE_DIR"/.prjinfo/sendmail/patches --cover-letter \
    --subject-prefix="$PREFIX" ${SINCE}..HEAD~${IGNORE_TOP}

# fixup the cover letter
(
    cd "$BASE_DIR"/.prjinfo/sendmail/patches;
    sed -i -e "s/\*\*\* SUBJECT HERE \*\*\*/${SUBJECT}/"  0000-cover-letter.patch
    sed -i -e "/\*\*\* BLURB HERE \*\*\*/ r ../cover.txt" 0000-cover-letter.patch
    sed -i -e "/\*\*\* BLURB HERE \*\*\*/ d" 0000-cover-letter.patch
)

git send-email --to="$TO" --cc="$CC" $EXTRA_SEND_OPTS \
    "$BASE_DIR"/.prjinfo/sendmail/patches
