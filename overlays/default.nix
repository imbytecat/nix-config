{ inputs }:

inputs.nixpkgs.lib.composeManyExtensions [

  (final: prev: {
    # 从 pin 的旧 revision 取 insecure-pnpm 受害包（原因/退出条件见 docs/adr/0002-pnpm-pin.md）
    inherit (inputs.nixpkgs-pnpm-pin.legacyPackages.${final.stdenv.hostPlatform.system})
      cherry-studio
      ;

    # freecad → vtk → gdal-minimal：3.13.1 的 test_zarr_read_simple_sharding
    # 在 CACHE_TILE_PRESENCE 下不写 zarr.json.gmac，本机构建挂掉；上游未 disabled 前先跳过
    gdal = prev.gdal.overrideAttrs (old: {
      disabledTests = (old.disabledTests or [ ]) ++ [
        "test_zarr_read_simple_sharding"
      ];
    });
  })

]
