# Nullata Image for MariaDB Galera

## What is MariaDB Galera?

> MariaDB Galera is a multi-primary database cluster solution for synchronous replication and high availability.

[Overview of MariaDB Galera](https://mariadb.com/kb/en/library/galera-cluster/)
Trademarks: This software listing is packaged by Nullata. The respective trademarks mentioned in the offering are owned by the respective companies, and use of them does not imply any affiliation or endorsement.

## TL;DR

```console
docker run --name mariadb \
  -e ALLOW_EMPTY_PASSWORD=yes \
  nullata/mariadb-galera:latest
```

**⚠️ Warning ⚠️**: Quick setups are only intended for development environments. You are encouraged to change the insecure default credentials and check out the available configuration options in the [Configuration](#configuration) section for a more secure deployment.

__✨ For production deployments, refer to the example Docker Compose setups available in the GitHub repository for each respective version. These include multi-node configurations and recommended environment settings for different versions.__

## Get this image

The recommended way to get the Nullata MariaDB Galera Docker Image is to pull the prebuilt image from the [Docker Hub Registry](https://hub.docker.com/r/nullata/mariadb-galera).

```console
docker pull nullata/mariadb-galera:latest
```

To use a specific version, you can pull a versioned tag. You can view the [list of available versions](https://hub.docker.com/r/nullata/mariadb-galera/tags) in the Docker Hub Registry.

```console
docker pull nullata/mariadb-galera:[TAG]
```

## Persisting your database

If you remove the container all your data will be lost, and the next time you run the image the database will be reinitialized. To avoid this loss of data, you should mount a volume that will persist even after the container is removed.

For persistence you should mount a directory at the `/nullata/mariadb` path. If the mounted directory is empty, it will be initialized on the first run.

```console
docker run \
    -e ALLOW_EMPTY_PASSWORD=yes \
    -v /path/to/mariadb-persistence:/nullata/mariadb \
    nullata/mariadb-galera:latest
```

or by modifying the `docker-compose.yml` file present in each respective version directory in this repository:

```yaml
services:
  mariadb:
  ...
    volumes:
      - /path/to/mariadb-persistence:/nullata/mariadb
  ...
```

## Connecting to other containers

Using [Docker container networking](https://docs.docker.com/engine/userguide/networking/), a MariaDB server running inside a container can easily be accessed by your application containers.

Containers attached to the same network can communicate with each other using the container name as the hostname.

### Using the Command Line

In this example, we will create a MariaDB client instance that will connect to the server instance that is running on the same docker network as the client.

#### Step 1: Create a network

```console
docker network create app --driver bridge
```

#### Step 2: Launch the MariaDB server instance

Use the `--network app` argument to the `docker run` command to attach the MariaDB container to the `app` network.

```console
docker run -d --name mariadb-galera \
    -e ALLOW_EMPTY_PASSWORD=yes \
    --network app \
    nullata/mariadb-galera:latest
```

#### Step 3: Launch your MariaDB client instance

Finally we create a new container instance to launch the MariaDB client and connect to the server created in the previous step:

```console
docker run -it --rm \
    --network app \
    nullata/mariadb-galera:latest mysql -h mariadb-galera -u root
```

### Using a Docker Compose file

When not specified, Docker Compose automatically sets up a new network and attaches all deployed services to that network. However, we will explicitly define a new `bridge` network named `database`. In this example we assume that you want to connect to the MariaDB server from your own custom application image which is identified in the following snippet by the service name `myapp`.

```yaml
version: '2'

networks:
  app:
    driver: bridge
  database:
    driver: bridge

services:
  mariadb-galera:
    image: nullata/mariadb-galera:latest
    environment:
      - ALLOW_EMPTY_PASSWORD=yes
    networks:
      - database

  myapp:
    image: YOUR_APPLICATION_IMAGE
    networks:
      - app
      - database
```

Launch the containers using:

```console
docker-compose up -d
```

## Configuration

### Environment variables

#### Customizable environment variables

| Name                                          | Description                                                                                                               | Default Value                             |
|-----------------------------------------------|---------------------------------------------------------------------------------------------------------------------------|-------------------------------------------|
| `ALLOW_EMPTY_PASSWORD`                        | Allow MariaDB Galera access without any password.                                                                         | `no`                                      |
| `MARIADB_AUTHENTICATION_PLUGIN`               | MariaDB Galera authentication plugin to configure during the first initialization.                                        | `nil`                                     |
| `MARIADB_ROOT_USER`                           | MariaDB Galera database root user.                                                                                        | `root`                                    |
| `MARIADB_ROOT_PASSWORD`                       | MariaDB Galera database root user password.                                                                               | `nil`                                     |
| `MARIADB_USER`                                | MariaDB Galera database user to create during the first initialization.                                                   | `nil`                                     |
| `MARIADB_PASSWORD`                            | Password for the MariaDB Galera database user to create during the first initialization.                                  | `nil`                                     |
| `MARIADB_DATABASE`                            | MariaDB Galera database to create during the first initialization.                                                        | `nil`                                     |
| `MARIADB_MASTER_HOST`                         | Address for the MariaDB Galera master node.                                                                               | `nil`                                     |
| `MARIADB_MASTER_PORT_NUMBER`                  | Port number for the MariaDB Galera master node.                                                                           | `3306`                                    |
| `MARIADB_MASTER_ROOT_USER`                    | MariaDB Galera database root user of the master host.                                                                     | `root`                                    |
| `MARIADB_MASTER_ROOT_PASSWORD`                | Password for the MariaDB Galera database root user of the the master host.                                                | `nil`                                     |
| `MARIADB_MASTER_DELAY`                        | MariaDB Galera database replication delay.                                                                                | `0`                                       |
| `MARIADB_REPLICATION_USER`                    | MariaDB Galera replication database user.                                                                                 | `nil`                                     |
| `MARIADB_REPLICATION_PASSWORD`                | Password for the MariaDB Galera replication database user.                                                                | `nil`                                     |
| `MARIADB_PORT_NUMBER`                         | Port number to use for the MariaDB Galera Server service.                                                                 | `nil`                                     |
| `MARIADB_REPLICATION_MODE`                    | MariaDB Galera replication mode.                                                                                          | `nil`                                     |
| `MARIADB_REPLICATION_SLAVE_DUMP`              | Make a dump on master and update slave MariaDB Galera database                                                            | `false`                                   |
| `MARIADB_EXTRA_FLAGS`                         | Extra flags to be passed to start the MariaDB Galera Server.                                                              | `nil`                                     |
| `MARIADB_INIT_SLEEP_TIME`                     | Sleep time when waiting for MariaDB Galera init configuration operations to finish.                                       | `nil`                                     |
| `MARIADB_CHARACTER_SET`                       | MariaDB Galera collation to use.                                                                                          | `nil`                                     |
| `MARIADB_COLLATE`                             | MariaDB Galera collation to use.                                                                                          | `nil`                                     |
| `MARIADB_BIND_ADDRESS`                        | MariaDB Galera bind address.                                                                                              | `nil`                                     |
| `MARIADB_SQL_MODE`                            | MariaDB Galera Server SQL modes to enable.                                                                                | `nil`                                     |
| `MARIADB_UPGRADE`                             | MariaDB Galera upgrade option.                                                                                            | `AUTO`                                    |
| `MARIADB_SKIP_TEST_DB`                        | Whether to skip creating the test database.                                                                               | `no`                                      |
| `MARIADB_CLIENT_ENABLE_SSL`                   | Whether to force SSL for connections to the MariaDB Galera database.                                                      | `no`                                      |
| `MARIADB_CLIENT_SSL_CA_FILE`                  | Path to CA certificate to use for SSL connections to the MariaDB Galera database server.                                  | `nil`                                     |
| `MARIADB_CLIENT_SSL_CERT_FILE`                | Path to client public key certificate to use for SSL connections to the MariaDB Galera database server.                   | `nil`                                     |
| `MARIADB_CLIENT_SSL_KEY_FILE`                 | Path to client private key to use for SSL connections to the MariaDB Galera database server.                              | `nil`                                     |
| `MARIADB_CLIENT_EXTRA_FLAGS`                  | Whether to force SSL connections with the "mysql" CLI tool. Useful for applications that rely on the CLI instead of APIs. | `no`                                      |
| `MARIADB_STARTUP_WAIT_RETRIES`                | Number of retries waiting for the database to be running.                                                                 | `300`                                     |
| `MARIADB_STARTUP_WAIT_SLEEP_TIME`             | Sleep time between retries waiting for the database to be running.                                                        | `2`                                       |
| `MARIADB_ENABLE_SLOW_QUERY`                   | Whether to enable slow query logs.                                                                                        | `0`                                       |
| `MARIADB_LONG_QUERY_TIME`                     | How much time, in seconds, defines a slow query.                                                                          | `10.0`                                    |
| `MARIADB_GALERA_DEFAULT_NODE_NAME`            | Default logical name that the node will use to refer to itself in the Galera cluster.                                     | `nil`                                     |
| `MARIADB_GALERA_DEFAULT_NODE_ADDRESS`         | Default node address to report to the Galera cluster.                                                                     | `nil`                                     |
| `MARIADB_GALERA_DEFAULT_MARIABACKUP_PASSWORD` | Default password for the username to use with the "mariabackup" tool for State Snapshot Transfer (SST).                   | `nil`                                     |
| `MARIADB_GALERA_CONF_DIR`                     | MariaDB Galera configuration directory                                                                                    | `/opt/nullata/mariadb/conf`               |
| `MARIADB_GALERA_MOUNTED_CONF_DIR`             | Directory for including custom configuration files (that override the default generated ones)                             | `/nullata/conf`                           |
| `MARIADB_GALERA_FORCE_SAFETOBOOTSTRAP`        | Whether bootstrapping should be performed even if the node is marked as not safe to bootstrap.                            | `nil`                                     |
| `MARIADB_GALERA_CLUSTER_BOOTSTRAP`            | Whether the node should be the one performing the bootstrap process of the Galera cluster.                                | `nil`                                     |
| `MARIADB_GALERA_CLUSTER_ADDRESS`              | Galera cluster address.                                                                                                   | `nil`                                     |
| `MARIADB_GALERA_CLUSTER_NAME`                 | Galera cluster name.                                                                                                      | `$DB_GALERA_DEFAULT_CLUSTER_NAME`         |
| `MARIADB_GALERA_NODE_NAME`                    | Logical name that the node uses to refer to itself in the Galera cluster, defaults to the node hostname.                  | `nil`                                     |
| `MARIADB_GALERA_NODE_ADDRESS`                 | Node address to report to the Galera cluster, defaults to the node IP address.                                            | `nil`                                     |
| `MARIADB_GALERA_SST_METHOD`                   | State Snapshot Transfer (SST) method to use.                                                                              | `$DB_GALERA_DEFAULT_SST_METHOD`           |
| `MARIADB_GALERA_MARIABACKUP_USER`             | Username to use with the "mariabackup" tool for State Snapshot Transfer (SST).                                            | `$DB_GALERA_DEFAULT_MARIABACKUP_USER`     |
| `MARIADB_GALERA_MARIABACKUP_PASSWORD`         | Password for the username to use with the "mariabackup" tool for State Snapshot Transfer (SST).                           | `$DB_GALERA_DEFAULT_MARIABACKUP_PASSWORD` |
| `MARIADB_ENABLE_LDAP`                         | Whether to enable LDAP for MariaDB Galera.                                                                                | `no`                                      |
| `MARIADB_ENABLE_TLS`                          | Whether to enable SSL/TLS for MariaDB Galera.                                                                             | `no`                                      |
| `MARIADB_TLS_CERT_FILE`                       | Path to the MariaDB Galera SSL/TLS certificate file.                                                                      | `nil`                                     |
| `MARIADB_TLS_KEY_FILE`                        | Path to the MariaDB Galera SSL/TLS certificate key file.                                                                  | `nil`                                     |
| `MARIADB_TLS_CA_FILE`                         | Path to the MariaDB Galera SSL/TLS certificate authority CA file.                                                         | `nil`                                     |
| `MARIADB_REPLICATION_USER`                    | MariaDB Galera replication database user.                                                                                 | `monitor`                                 |
| `MARIADB_REPLICATION_PASSWORD`                | Password for the MariaDB Galera replication database user.                                                                | `monitor`                                 |

#### Read-only environment variables

| Name                                      | Description                                                                                                         | Value                             |
|-------------------------------------------|---------------------------------------------------------------------------------------------------------------------|-----------------------------------|
| `DB_FLAVOR`                               | SQL database flavor. Valid values: `mariadb` or `mysql`.                                                            | `mariadb`                         |
| `DB_BASE_DIR`                             | Base path for MariaDB Galera files.                                                                                 | `${NULLATA_ROOT_DIR}/mariadb`     |
| `DB_VOLUME_DIR`                           | MariaDB Galera directory for persisted files.                                                                       | `${NULLATA_VOLUME_DIR}/mariadb`   |
| `DB_DATA_DIR`                             | MariaDB Galera directory for data files.                                                                            | `${DB_VOLUME_DIR}/data`           |
| `DB_BIN_DIR`                              | MariaDB Galera directory where executable binary files are located.                                                 | `${DB_BASE_DIR}/bin`              |
| `DB_SBIN_DIR`                             | MariaDB Galera directory where service binary files are located.                                                    | `${DB_BASE_DIR}/sbin`             |
| `DB_CONF_DIR`                             | MariaDB Galera configuration directory.                                                                             | `${DB_BASE_DIR}/conf`             |
| `DB_DEFAULT_CONF_DIR`                     | MariaDB Galera default configuration directory.                                                                     | `${DB_BASE_DIR}/conf.default`     |
| `DB_LOGS_DIR`                             | MariaDB Galera logs directory.                                                                                      | `${DB_BASE_DIR}/logs`             |
| `DB_TMP_DIR`                              | MariaDB Galera directory for temporary files.                                                                       | `${DB_BASE_DIR}/tmp`              |
| `DB_CONF_FILE`                            | Main MariaDB Galera configuration file.                                                                             | `${DB_CONF_DIR}/my.cnf`           |
| `DB_PID_FILE`                             | MariaDB Galera PID file.                                                                                            | `${DB_TMP_DIR}/mysqld.pid`        |
| `DB_SOCKET_FILE`                          | MariaDB Galera Server socket file.                                                                                  | `${DB_TMP_DIR}/mysql.sock`        |
| `DB_DAEMON_USER`                          | Users that will execute the MariaDB Galera Server process.                                                          | `mysql`                           |
| `DB_DAEMON_GROUP`                         | Group that will execute the MariaDB Galera Server process.                                                          | `mysql`                           |
| `MARIADB_DEFAULT_PORT_NUMBER`             | Default port number to use for the MariaDB Galera Server service.                                                   | `3306`                            |
| `MARIADB_DEFAULT_CHARACTER_SET`           | Default MariaDB Galera character set.                                                                               | `utf8mb4`                         |
| `MARIADB_DEFAULT_BIND_ADDRESS`            | Default MariaDB Galera bind address.                                                                                | `0.0.0.0`                         |
| `MARIADB_GALERA_GRASTATE_FILE`            | Path to the Galera "grastate.dat" file.                                                                             | `${DB_DATA_DIR}/grastate.dat`     |
| `MARIADB_GALERA_BOOTSTRAP_DIR`            | Path to the Galera directory that will contain a file for checking whether the node is already bootstrapped or not. | `${DB_VOLUME_DIR}/.bootstrap`     |
| `MARIADB_GALERA_BOOTSTRAP_FILE`           | Path to the Galera file that will check whether the node is already bootstrapped or not.                            | `${DB_GALERA_BOOTSTRAP_DIR}/done` |
| `MARIADB_GALERA_DEFAULT_CLUSTER_ADDRESS`  | Default Galera cluster address.                                                                                     | `gcomm://`                        |
| `MARIADB_GALERA_DEFAULT_CLUSTER_NAME`     | Default Galera cluster name.                                                                                        | `galera`                          |
| `MARIADB_GALERA_DEFAULT_SST_METHOD`       | Default State Snapshot Transfer (SST) method to use.                                                                | `mariabackup`                     |
| `MARIADB_GALERA_DEFAULT_MARIABACKUP_USER` | Default username to use with the "mariabackup" tool for State Snapshot Transfer (SST).                              | `mariabackup`                     |

