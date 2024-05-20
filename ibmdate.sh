#!/bin/bash

VERSION="1.0"
NAMESPACE=""
ALL_NAMESPACE=""
INSTANCE=""
FILE_NAME_OUTPUT=""
WORKSPACE_FOLDER=`pwd`/date_last_modified
RESULT="date_last_modified-$(date '+%Y.%m.%d_%H_%M_%S').txt"
FILENAME_EXISTS=("`pwd`/output.txt" "`pwd`/script.sh" "`pwd`/data.txt","`pwd`/run.sh","`pwd`/${RESULT}")

MAINTAINER="hungtn29@fpt.com"

print_help() {
    echo "MAINTAINER version ${VERSION}: ${MAINTAINER}"
    echo "Usage: ibmdate [options]"
    echo "Options:"
    echo "  -n, --namespaces <ns>      Set namespace"
    echo "  -A, --all                  All namespace"
    echo "  -i, --instance <instance>  Set instance"
    echo "  -o, --output <name file>   File name output"
    echo "  -h, --help                 Show help message"
    echo "  -v, --version              Show version information"
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            -h|--help)
                print_help
                exit 0
                ;;
            -v|--version)
                echo "ibmdate version $VERSION"
                exit 0
                ;;
            -n|--namespace)
                shift
                NAMESPACE="$1"
                ;;
            -i|--instance)
                shift
                INSTANCE="$1"
                ;;
            -A|--all-namespaces)
                shift
                ALL_NAMESPACE="$1"
                ;;
            *)
                echo "Unknown option: $key"
                echo "Use -h or --help to see available options."
                echo "=========================================="
                print_help
                exit 1
                ;;
        esac
        shift
    done
}

getDateLastModifiedByNamespace() {
  local namespace="${1:-default}"
  local instance="${2}"

  # If specifies IBM ACE instance in this namespace
  if [[ -z "${instance}" ]]; then
    user_passwd=$( oc get secret -n $namespace ${instance} -o json | jq -r '.data.adminusers' | base64 -d )
    user=$( echo $user_passwd | cut -d ' ' -f 1 )
    passwd=$( echo $user_passwd | cut -d ' ' -f 2 )
    pod_name=$( oc -n $namespace get po | grep Running | grep $instance | head -n 1 | awk '{print $1}' )

    echo "oc -n $namespace rsh $pod_name curl --cert /home/aceuser/adminssl/tls.crt.pem --key /home/aceuser/adminssl/tls.key.pem -k -X GET https://localhost:7600/apiv2/applications -u ${user}:${passwd} | jq -r  '.children[].uri' | while read name; do printf '%s\n' \$name >> data.txt; done;" >> script.sh
    echo "oc -n $namespace rsh $pod_name curl --cert /home/aceuser/adminssl/tls.crt.pem --key /home/aceuser/adminssl/tls.key.pem -k -X GET https://localhost:7600/apiv2/policies -u ${user}:${passwd} | jq -r  '.children[].uri' | while read name; do printf '%s\n' \$name >> data.txt; done;" >> script.sh
    echo "oc -n $namespace rsh $pod_name curl --cert /home/aceuser/adminssl/tls.crt.pem --key /home/aceuser/adminssl/tls.key.pem -k -X GET https://localhost:7600/apiv2/shared-libraries -u ${user}:${passwd} | jq -r  '.children[].uri' | while read name; do printf '%s\n' \$name >> data.txt; done;" >> script.sh

    chmod +x script.sh
    bash script.sh

    while read line
    do
      uri=$( echo $line | cut -d ' ' -f 1 )

      echo "oc -n $namespace rsh $pod_name curl --cert /home/aceuser/adminssl/tls.crt.pem --key /home/aceuser/adminssl/tls.key.pem -k -X GET https://localhost:7600${uri} -u ${user}:${passwd} | jq -rc '.descriptiveProperties.lastModified + \" \" + (.name | tostring ) + \" \" + \"$namespace\" + \" \" + \"$pod_name\"' >> $RESULT" >> run.sh
    done < data.txt

    chmod +x run.sh
    bash run.sh

    cat $RESULT

  else
  # Else get all instance IBM ACE in this namespace
    oc get IntegrationRuntime -n ${namespace} --no-headers | awk '{print $1}' > common.txt

    while read line
    do
      instance=$( echo $line )
      output=$( oc get secret -n $namespace ${instance} -o json | jq -r '.data.adminusers' | base64 -d )
      pod_name=$( oc get po -n $namespace | grep $instance | head -n 1 | awk '{print $1}' )

      printf '%s %s %s\n' "$namespace" "$pod_name" "$output " >> output.txt
    done < common.txt

    while read line
    do
      NAMESPACE=$( echo $line | cut -d ' ' -f 1 )
      POD_NAME=$( echo $line | cut -d ' ' -f 2 )
      USER=$( echo $line | cut -d ' ' -f 3 )
      PASSWD=$( echo $line | cut -d ' ' -f 4 )

      echo "oc -n $NAMESPACE rsh $POD_NAME curl --cert /home/aceuser/adminssl/tls.crt.pem --key /home/aceuser/adminssl/tls.key.pem -k -X GET https://localhost:7600/apiv2/applications -u ${USER}:${PASSWD} | jq -r  '.children[].uri' | while read name; do printf '%s %s %s %s %s\n' \$name $NAMESPACE $POD_NAME $USER $PASSWD >> data.txt; done;" >> script.sh
      echo "oc -n $NAMESPACE rsh $POD_NAME curl --cert /home/aceuser/adminssl/tls.crt.pem --key /home/aceuser/adminssl/tls.key.pem -k -X GET https://localhost:7600/apiv2/policies -u ${USER}:${PASSWD} | jq -r  '.children[].uri' | while read name; do printf '%s %s %s %s %s\n' \$name $NAMESPACE $POD_NAME $USER $PASSWD >> data.txt; done;" >> script.sh  
      echo "oc -n $NAMESPACE rsh $POD_NAME curl --cert /home/aceuser/adminssl/tls.crt.pem --key /home/aceuser/adminssl/tls.key.pem -k -X GET https://localhost:7600/apiv2/shared-libraries -u ${USER}:${PASSWD} | jq -r  '.children[].uri' | while read name; do printf '%s %s %s %s %s\n' \$name $NAMESPACE $POD_NAME $USER $PASSWD >> data.txt; done;" >> script.sh
    done < output.txt

    chmod +x script.sh
    bash script.sh

  fi
}

parse_arguments "$@"

for filename in "${FILENAME_EXISTS[@]}"; do
    if [ -e "$filename" ]; then
        #echo "File $filename exists. Removing..."
        rm "$filename"
        #echo "File $filename removed."
    #else
        #echo "File $filename does not exist."
    fi
done

if [[ -z $@ ]]; then
  echo "Pleae inject argument"
  exit 1;
fi

if [[ -z "${NAMESPACE}" ]]; then
  if [[ ! -z ${ALL_NAMESPACE} ]]; then
    echo "-A or --all-namespaces not argument"
  else
    echo getDateLastModifiedAllNamespace
  fi
else
  if [[ -z ${INSTANCE} ]]; then
    echo "Namespace is ${NAMESPACE}"
  else
    echo "Get Instance $INSTANCE in Namespace $NAMESPACE"
  fi
fi