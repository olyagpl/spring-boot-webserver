{
  specVersion: "2",
  local jekyll_common(version) = {
    capabilities: ["linux", "amd64"],
    # Necessary to use the precompiled nokogiri
    docker: {
      image: "phx.ocir.io/oraclelabs2/c_graal/buildslave:buildslave_ol7",
      mount_modules: true,
    },
    packages: {
      ruby: "==2.6.6",
      libffi: ">=3.2.1",
      nodejs: ">=8.9.4",
      git: ">=2.9.3",
    },
    downloads: {
      LIBGMP: {name: "libgmp", version: "6.1.0", platformspecific: true}
    },
    environment: {
      JEKYLL_ENV: "production",
      BUNDLE_PATH: "$PWD/../bundle-path",
      CPPFLAGS: "-I$LIBGMP/include",
      LD_LIBRARY_PATH: "$LIBGMP/lib:$LD_LIBRARY_PATH",
      LIBRARY_PATH: "$LIBGMP/lib:$LIBRARY_PATH",
      CI: "true",
      DOCS_VERSION: version
    },
    timelimit: "20:00",
    setup: [
      ["mkdir", "../gem-home"],
      ["export", "GEM_HOME=$PWD/../gem-home"],
      ["gem", "install", "--no-document", "bundler", "-v", "2.1.4"],
      ["export", "PATH=$GEM_HOME/bin:$PATH"],
      ["bundle", "install"],
    ],
  },

  local jekyll_build(version) = jekyll_common(version) + {
    run: [
      ["gem", "install", "nokogiri", "-v", "1.13.10"],
      ["./_scripts/build.sh"],
      ["head", version + "/index.html"],
      ["echo", "Checking that top-level directory has no unexpected entries"],
      ["ls", "-1", version, "|", "sort", ">", "_actual-sorted-output.txt"],
      ["sort", "_scripts/expected-output.txt", ">", "_expected-sorted-output.txt"],
      ["diff", "_actual-sorted-output.txt", "_expected-sorted-output.txt", "||", "exit", "23"],
    ],
    publishArtifacts: [
      {
        name: "jekyll_build_artifact_" + version,
        dir: version,
        patterns: ["*"],
      }
    ]
  },

  local publish_staging(version) = {
    capabilities: ["linux", "amd64"],
    requireArtifacts: [
      {
        name: "jekyll_build_artifact_" + version,
        dir: version,
      }
    ],
    run: [
      ["rsync", "-rlv", "-e", "ssh -p 2224 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no", "--exclude-from", "_rsync-excluded", version + "/", "graal@ol-graal-infra4.oraclecorp.com:/var/www/html/" + version]
    ]
  },

  local publish_github(version) = {
    capabilities: ["linux", "amd64"],
    requireArtifacts: [
      {
        name: "jekyll_build_artifact_" + version,
        dir: version,
      }
    ],
    run: [
      ["git", "clone", "ssh://git@ol-bitbucket.us.oracle.com:7999/g/graalvm-website.git"],
      ["rsync", "-a", "--delete", "--exclude-from", "_rsync-excluded", "--filter", "P /*/javadoc/", version + "/", "graalvm-website/" + version],
      ["git", "-C", "graalvm-website", "add", "."],
      ["git", "-C", "graalvm-website", "status"],
      ["git", "-C", "graalvm-website", "-c", "user.name=Web Publisher", "-c", "user.email=graalvm-dev@oss.oracle.com", "commit", "-m", "Update website"],
      ["git", "-C", "graalvm-website", "push", "origin", "HEAD"],
      ["git", "branch", "--force", "--no-track", "published"],
      ["git", "push", "--force", "origin", "published"],
    ]
  },

  builds: std.flattenArrays([[
    jekyll_build(version) + {name: "jekyll-build-"+version, targets: ["gate"]},
    publish_staging(version) + {name: "deploy-staging-"+version, targets: ["deploy"] }, # execute manually
    publish_github(version)  + {name: "deploy-production-"+version, targets: ["deploy"]}, # execute manually
  ] for version in ["21.3", "22.0", "22.1", "22.2", "22.3", "jdk20"]])
}