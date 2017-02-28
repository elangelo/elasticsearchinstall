clustername="es_saas_adam"
nodename="fiona"
nodemaster="true"

srcdir=$(pwd)
_pkgname="elasticsearch"
pkgver="1.7.3"
pkgdir="$srcdir/install"

function download {
  curl https://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-1.7.3.tar.gz -o elasticsearch-1.7.3.tar.gz 
  tar xzf elasticsearch-1.7.3.tar.gz 
}

function prepare {
  cd "$srcdir"/$_pkgname-$pkgver

  for script in plugin elasticsearch; do
    sed 's|^ES_HOME=.*dirname.*|ES_HOME=/usr/share/elasticsearch|' \
      -i bin/$script
  done

  sed 's|$ES_HOME/lib|/usr/lib/elasticsearch|g' -i bin/elasticsearch.in.sh bin/plugin

  echo -e '\nJAVA_OPTS="$JAVA_OPTS -Des.path.conf=/etc/elasticsearch"' >> bin/elasticsearch.in.sh

  sed -re 's;#\s*(path\.conf:).*$;\1 /etc/elasticsearch;' \
    -e '0,/#\s*(path\.data:).*$/s;;\1 /var/lib/elasticsearch;' \
    -e 's;#\s*(path\.work:).*$;\1 /tmp/elasticsearch;' \
    -e 's;#\s*(path\.logs:).*$;\1 /var/log/elasticsearch;' \
    -i config/elasticsearch.yml

cat <<EOF >> config/elasticsearch.yml
script.disable_dynamic: false
index.load_fixed_bitset_filters_eagerly: false
cluster.name: $clustername
node.name: $nodename
node.master: $nodemaster
discovery.zen.ping.multicast.enabled: false
EOF
}

function user {
  sudo useradd elasticsearch -r -u 114
}

function package {
  cd "$srcdir"/$_pkgname-$pkgver
  install -dm755 "$pkgdir"/etc/elasticsearch

  install -Dm644 lib/sigar/libsigar-amd64-linux.so "$pkgdir"/usr/lib/elasticsearch/sigar/libsigar-amd64-linux.so
  cp lib/sigar/sigar*.jar "$pkgdir"/usr/lib/elasticsearch/sigar/
  cp lib/*.jar "$pkgdir"/usr/lib/elasticsearch/

  cp config/* "$pkgdir"/etc/elasticsearch/

  install -Dm755 bin/elasticsearch "$pkgdir"/usr/bin/elasticsearch
  install -Dm755 bin/plugin "$pkgdir"/usr/bin/elasticsearch-plugin
  install -Dm644 bin/elasticsearch.in.sh "$pkgdir"/usr/share/elasticsearch/elasticsearch.in.sh

  install -Dm644 "$srcdir"/elasticsearch.service "$pkgdir"/usr/lib/systemd/system/elasticsearch.service
  install -Dm644 "$srcdir"/elasticsearch@.service "$pkgdir"/usr/lib/systemd/system/elasticsearch@.service
  install -Dm644 "$srcdir"/elasticsearch-user.conf "$pkgdir"/usr/lib/sysusers.d/elasticsearch.conf
  install -Dm644 "$srcdir"/elasticsearch-tmpfile.conf "$pkgdir"/usr/lib/tmpfiles.d/elasticsearch.conf
  install -Dm644 "$srcdir"/elasticsearch-sysctl.conf "$pkgdir"/usr/lib/sysctl.d/elasticsearch.conf

  install -Dm644 "$srcdir"/elasticsearch.default "$pkgdir"/etc/default/elasticsearch

  ln -s ../../../var/lib/elasticsearch "$pkgdir"/usr/share/elasticsearch/data

  chown -R 114:114 "$pkgdir"/usr/share/elasticsearch
}

download
prepare
user
package

#still need to chown -R /usr/share/elasticsearch and /run/elasticsearch need to find a better way
