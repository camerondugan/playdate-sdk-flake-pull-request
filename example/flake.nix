{
  inputs = {
    playdate-sdk.url = "github:RegularTetragon/playdate-sdk-flake";
  };
  outputs = {self, nixpkgs, playdate-sdk, ...}: 
  let system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      stdenv = pkgs.stdenv;
      playdate-sdk-pkg = playdate-sdk.packages.${system}.default;
      game-name = "hello_world.pdx";
  in
  {
    devShells.${system}.default = pkgs.mkShell {
      packages = [playdate-sdk-pkg];
      shellHook = ''
      export PLAYDATE_SDK_PATH=`pwd`/.PlaydateSDK
      '';
    };
    packages.${system} = {
      default = self.packages.${system}.playdate-example;
      playdate-example = with stdenv; mkDerivation {
        pname = "playdate-example";
        version = "1.0.0";
        src = with pkgs.lib.fileset; toSource {
          root = ./.;
          fileset = unions [
            ./CMakeLists.txt
            ./src
            ./Source
          ];
        };
        outName = game-name;
        nativeBuildInputs = [playdate-sdk-pkg pkgs.gcc-arm-embedded pkgs.cmake];
        buildInputs = [ playdate-sdk-pkg ];
        cmakeFlags = ["-DPLAYDATE_SDK_PATH=`pwd`/.PlaydateSDK"];
        configurePhase =  ''
        export PLAYDATE_SDK_PATH=${playdate-sdk-pkg}
        mkdir build
        cd build
        cmake $cmakeFlags ..
        make
        cd ..
        '';
        installPhase = ''
          export PLAYDATE_SDK_PATH=`pwd`/.PlaydateSDK
          runHook preInstall
          cp -r . $out
          mkdir $out/bin
          cat > $out/bin/${self.packages.${system}.default.pname} <<EOL
          #!/usr/bin/env bash
          ${playdate-sdk-pkg}/bin/PlaydateSimulator $out/${game-name}
          EOL
          chmod 555 $out/bin/${self.packages.${system}.default.pname}
          cd $out
          ${pkgs.zip}/bin/zip -r ${game-name}.zip ${game-name}
          runHook postInstall
        '';
      };
      playdate-example-arm = self.packages.${system}.playdate-example.overrideAttrs (final: prev: {
        pname = prev.pname + "-arm";
        cmakeFlags = ["-DCMAKE_TOOLCHAIN_FILE=${playdate-sdk-pkg}/C_API/buildsupport/arm.cmake"];
      });
    };
  };
}
