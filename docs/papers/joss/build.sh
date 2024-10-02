 podman run --rm --volume $PWD://data --user $(id -u):$(id -g) --env JOURNAL=joss openjournals/inara:latest
