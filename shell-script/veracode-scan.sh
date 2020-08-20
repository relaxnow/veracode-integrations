#/bin/bash
        # This was originally written for CircleCI but can be used for any build system that can run a shell script
        #$1 API-ID
        #$2 API-Key
        #$3 AppName
        #$4 Sandbox name
        #$5 Build working directory
        #$6 Build version (Scan name)

        PRESCAN_SLEEP_TIME=60
        SCAN_SLEEP_TIME=120
        JAVA_WRAPPER_LOCATION="."
        OUTPUT_FILE_LOCATION="/root/vera/build/"
        OUTPUT_FILE_NAME=$3'-'$5'.txt'
        echo '[INFO] ------------------------------------------------------------------------'
        echo '[INFO] DOWNLOADING VERACODE JAVA WRAPPER'
        if `wget https://repo1.maven.org/maven2/com/veracode/vosp/api/wrappers/vosp-api-wrappers-java/17.11.4.9/vosp-api-wrappers-java-17.11.4.9.jar -O VeracodeJavaAPI.jar`; then
                chmod 755 VeracodeJavaAPI.jar
                echo '[INFO] SUCCESSFULLY DOWNLOADED WRAPPER'
        else
                echo '[ERROR] DOWNLOAD FAILED'
                exit 1
        fi


        echo '[INFO] ------------------------------------------------------------------------'
        echo '[INFO] VERACODE UPLOAD AND SCAN'

        app_ID=$(java -verbose -jar $JAVA_WRAPPER_LOCATION/VeracodeJavaAPI.jar -vid $1 -vkey $2 -action GetAppList | grep -w "$3" | sed -n 's/.* app_id=\"\([0-9]*\)\" .*/\1/p')

        if [ -z "$app_ID" ];
        then
             echo '[INFO] App does not exist'
             echo '[INFO] create app: ' $3
             creat_addp=$(java -jar $JAVA_WRAPPER_LOCATION/VeracodeJavaAPI.jar -vid $1 -vkey $2 -action createApp -appname "$3" -criticality high)
             echo '[INFO]app created'
             app_ID=$(java -jar $JAVA_WRAPPER_LOCATION/VeracodeJavaAPI.jar -vid $1 -vkey $2 -action GetAppList | grep -w "$3" | sed -n 's/.* app_id=\"\([0-9]*\)\" .*/\1/p')
             echo '[INFO] new App-ID: ' $app_ID
             echo ""
        else
             echo '[INFO] App-IP: ' $app_ID
             echo ""
        fi



        echo ""
        echo '====== DEBUG START ======'
        echo 'API-ID: ' $1
        echo 'API-Key: ' $2
        echo 'App-Name: ' $3
        echo 'APP-ID: ' $app_ID
        echo 'Sandbox-Name: ' $4
        echo 'File-Path: ' $5
        echo 'Scan-Name: ' $6
        echo '====== DEBUG END ======'
        echo ""


        echo '[INFO] VERACODE scan pre-checks'
        echo '[INFO] directory checks'
        # Directory argument
        if [[ "$5" != "" ]]; then
             UPLOAD_DIR="$5"
        else
             echo "[ERROR] Directory not specified."
             exit 1
        fi

        # Check if directory exists
        if ! [[ -f "$UPLOAD_DIR" ]];
        then
             echo "[ERROR] File does not exist"
             exit 1
        else
             echo '[INFO] File set to '$UPLOAD_DIR
        fi

        # Version argument
        if [[ "$6" != "" ]];
        then
             VERSION=$6
        else
             VERSION=`date "+%Y-%m-%d %T"`    # Use date as default
        fi
        echo '[INFO] Scan-Name set to '$VERSION
        echo ""

        #Upload files, start prescan and scan
        echo '[INFO] upload and scan'
        java -jar $JAVA_WRAPPER_LOCATION/VeracodeJavaAPI.jar -vid $1 -vkey $2 -action uploadandscan -appname $3 -createprofile true -sandboxname $4 -filepath $5 -version $6 > $OUTPUT_FILE_LOCATION$OUTPUT_FILE_NAME 2>&1
        echo ""

        upload_scan_results=$(cat $OUTPUT_FILE_LOCATION$OUTPUT_FILE_NAME)

        if [[ $upload_scan_results == *"already exists"* ]];
        then
             echo ""
             echo '[ERROR] This scan name already exists'
             exit 1
        elif [[ $upload_scan_results == *"in progress or has failed"* ]];
        then
             echo ""
             echo '[ ERROR ] Something went wrong! A previous scan is in progress or has failed to complete successfully'
                exit 1
        else
             echo ""
             echo '[INFO] File(s) uploaded and PreScan started'
        fi

        #Get Build ID
        build_id=$(cat $OUTPUT_FILE_LOCATION$OUTPUT_FILE_NAME | grep build_id | awk -F "\"" '{print $2}')
        echo ""
        echo '====== DEBUG START ======'
        echo 'Build-ID: ' $build_id
        echo '====== DEBUG END ======'
        echo ""
        #Delete file
        rm -rf $OUTPUT_FILE_LOCATION$OUTPUT_FILE_NAME
