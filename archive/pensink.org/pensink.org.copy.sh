#!/bin/sh

# Change working directory
ABSPATH="$(cd "$(dirname "$0")"; pwd -P)"
cd $ABSPATH

# Paths
CONF_PATH="$ABSPATH/conf"

LIST_PAGES=$CONF_PATH/pages.txt
LIST_ASSETS=$CONF_PATH/assets.txt

for CHECKPATH in "$LIST_PAGES" "$LIST_ASSETS"
do
	if [ ! -f $CHECKPATH ]
	then
		>&2 echo "ERROR: Missing file '$CHECKPATH'."
		exit 1
	fi
done

# This is a workaround, because neither <IFS=\'n'> or <IFS=$(printf '\n')> will work in Dash
func_SET_IFS() {
	NEW_IFS="$1"

	eval "$(printf "IFS='$NEW_IFS'")"
}

# Don't forget to unset after using func_SET_IFS() if not executed within a subshell
func_RESTORE_IFS() {
	unset IFS
}

# Fetches all URLs in a list
func_PULL_ALL_FROM_LIST() {
	TYPE=$1
	LIST_PATH=$2
	APPEND_FILE_EXTENSION=$3
	
	func_SET_IFS '\n'
	for URL in `cat $LIST_PATH`
	do
		# Ignore comments
		if [ "${URL%${URL#\#}}" = "#" ]
		then
			continue
		fi
		
		# Remove leading slash
		URL="${URL#/}"
		
		# Basename (one/two/three.html => three.html)
		BASENAME=`basename "$URL"`
		FILE_EXTENSION="${BASENAME##*.}"
		
		if [ "$BASENAME" = "$FILE_EXTENSION" ]
		then
			FILE_EXTENSION=""
		fi
		
		# Get page path (one/two) and remove trailing slash
		PAGE_PATH="${URL%$BASENAME}"
		PAGE_PATH="${PAGE_PATH%/}"
		
		# Create missing paths
		CREATE_SAVE_PATH="$DEFAULT_SAVE_PATH/$PAGE_PATH"
		mkdir -p $CREATE_SAVE_PATH
		
		FULL_SAVE_PATH="$CREATE_SAVE_PATH/$BASENAME$APPEND_FILE_EXTENSION"
		DOWNLOAD_PATH="$SCHEME$FULL_HOSTNAME/$URL"
		
		# Download page
		if [ -f $FULL_SAVE_PATH ] && [ "$TYPE" = "asset" ]
		then
			if [ ! "$FILE_EXTENSION" = "css" ]
			then
				continue
			fi
		fi
		
		curl $DOWNLOAD_PATH --silent --output $FULL_SAVE_PATH
		
		if [ "`cat $FULL_SAVE_PATH`" = "" ]
		then
			rm $FULL_SAVE_PATH
			
			>&2 echo "ERROR: $DOWNLOAD_PATH not found."
			exit 1
		fi
		
		# Prepend GitHub path prefix in local URLs. Only absolute paths are covered.
		if [ "$TYPE" = "page" ]
		then
			sed -i "s#src=\"/#src=\"$GITHUB_PATH_SUFFIX/#g" $FULL_SAVE_PATH
			sed -i "s#href=\"/#href=\"$GITHUB_PATH_SUFFIX/#g" $FULL_SAVE_PATH
		fi
		
		if [ "$TYPE" = "asset" ] && [ "$FILE_EXTENSION" = "css" ]
		then
			sed -i "s#url(/#url($GITHUB_PATH_SUFFIX/#g" $FULL_SAVE_PATH
		fi
	done
	func_RESTORE_IFS
}

# Scheme
DEFAULT_SCHEME="https://"
read -p "URI Scheme [$DEFAULT_SCHEME]: " SCHEME
SCHEME=${SCHEME:-$DEFAULT_SCHEME}

# Full hostname of the website (including 'www' prefix where applicable)
DEFAULT_FULL_HOSTNAME="www.pensink.org"
read -p "Full Hostname (FQDN) [$DEFAULT_FULL_HOSTNAME]: " FULL_HOSTNAME
FULL_HOSTNAME=${FULL_HOSTNAME:-$DEFAULT_FULL_HOSTNAME}

# Hostname without 'www' prefix
DEFAULT_HOSTNAME="${FULL_HOSTNAME#www.}"
read -p "Hostname [$DEFAULT_HOSTNAME]: " HOSTNAME
HOSTNAME=${HOSTNAME:-$DEFAULT_HOSTNAME}

# Where the HTML renderings and assets are stored
DEFAULT_SAVE_PATH="/home/etkaar/work/etkaar.github.io/archive/pensink.org/src"
read -p "Save Path [$DEFAULT_SAVE_PATH]: " SAVE_PATH
SAVE_PATH=${SAVE_PATH:-$DEFAULT_SAVE_PATH}

# Paths in the HTML renderings (such as in <img src="...">) need to
# be prepended by the path on github.io.
#
# Only absolute paths are covered.
DEFAULT_GITHUB_PATH_PREFIX="/archive/$HOSTNAME/src"
read -p "GitHub Path Suffix [$DEFAULT_GITHUB_PATH_PREFIX]: " GITHUB_PATH_SUFFIX
GITHUB_PATH_SUFFIX=${GITHUB_PATH_SUFFIX:-$DEFAULT_GITHUB_PATH_PREFIX}

# Appends .html file extension to page files (LIST_PAGES)
DEFAULT_PAGE_FILE_EXTENSION=".html"
read -p "Page File Extension [$DEFAULT_PAGE_FILE_EXTENSION]: " PAGE_FILE_EXTENSION
PAGE_FILE_EXTENSION=${PAGE_FILE_EXTENSION:-$DEFAULT_PAGE_FILE_EXTENSION}

# Copy all pages and assets
func_PULL_ALL_FROM_LIST "page" "$LIST_PAGES" "$PAGE_FILE_EXTENSION"
func_PULL_ALL_FROM_LIST "asset" "$LIST_ASSETS" ""
