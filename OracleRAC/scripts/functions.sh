msg() {
  case $2 in
    1) local __msg="INFO:" ;;
    2) local __msg="ERROR:" ;;
    3) local __msg="SUCCESS:" ;;
  esac

  test -n "$3" && test $3 -le 1 && printf -- '-%.0s' {1..100}; printf '\n' 
  printf "%s %s: %s\n" "${__msg}" "$(date +%F' '%T)" "${1}"
  test -n "$3" && test $3 -ge 1 && printf -- '-%.0s' {1..100}; printf '\n'
}

info() {
  msg "$1" 1 "$2"
}

error() {
  msg "$1" 2 "$2"
  exit 1
}

success() {
  msg "$1" 3 "$2"
}

get_node_id() {
  echo "$(echo `hostname` | sed -e "s/^${VM_NAME}//")"
}

add_ips() {
  local __node_count="$1"
  local __basename="$2"
  local __domain="$3"
  local __comment="$4"
  local __ip="$5"
  local __suffix="$6"
  local __lan="$(echo "$__ip" | cut -d. -f1-3)"
  local __start="$(echo "$__ip" | cut -d. -f4)"

  printf "\n# %s\n" "$__comment" >> /etc/hosts
   for i in $(seq 1 $__node_count)
    do __ip="${__lan}.$((__start+i))"
       __host="${__basename}${i}${__suffix}"
       printf "%s\t%s\t%s\n" "${__ip}" "${__host}.${__domain}" "${__host}" >> /etc/hosts
  done
}

nodelist() {
  local __node_count="$1"
  local __basename="$2"
  local __suffix="$3"
  local __nodes=
   for i in $(seq 1 $__node_count)
    do __node="${__basename}${i}${__suffix}"
       test -z "${__nodes}" && __nodes="${__node}" || __nodes="${__nodes},${__node}"
  done
  echo "$__nodes"
}

cluster_nodelist() {
  local __node_count="$1"
  local __basename="$2"
  local __domain="$3"
  local __vip_name="$4"
  local __cluster_nodes=
   for i in $(seq 1 $__node_count)
    do __cluster_node="${__basename}${i}.${__domain}:${__basename}${i}${__vip_name}.${__domain}:HUB"
       test -z "${__cluster_nodes}" && __cluster_nodes="${__cluster_node}" || __cluster_nodes="${__cluster_nodes},${__cluster_node}"
  done
  echo "$__cluster_nodes"
}
