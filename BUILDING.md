# Building with Drone

After rebasing patches ontop of latest controller tag, you can test drone runs locally before pushing to github.
```
DRONE_TAG=nginx-1.7.1-hardened1rc3 drone exec --event tag --trusted --pipeline=ci
```

If you pass E2E and break on the publish step, you can simulate that step by adding `--secret-file=secrets.txt`.
Where secrets.txt is:
```
docker_password=
docker_username=<YOUR_DOCKERHUB_USER>
```