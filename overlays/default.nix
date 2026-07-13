{ inputs }:

inputs.nixpkgs.lib.composeManyExtensions [

  (final: prev: {
    # 从 pin 的旧 revision 取 insecure-pnpm 受害包（原因/退出条件见 docs/adr/0002-pnpm-pin.md）
    inherit (inputs.nixpkgs-pnpm-pin.legacyPackages.${final.stdenv.hostPlatform.system})
      cherry-studio
      ;

    # freecad → vtk → gdal-minimal：3.13.1 的 test_zarr_read_simple_sharding
    # 在 CACHE_TILE_PRESENCE 下不写 zarr.json.gmac，本机构建挂掉；上游未 disabled 前先跳过
    # https://github.com/NixOS/nixpkgs/pull/540826
    gdal = prev.gdal.overrideAttrs (old: {
      disabledTests = (old.disabledTests or [ ]) ++ [
        "test_zarr_read_simple_sharding"
      ];
    });

    # freecad → vtk → pdal：2.9.3 对 GDAL 3.13 GetMetadata→CSLConstList 不兼容，编译失败
    # 上游补丁：https://github.com/PDAL/PDAL/commit/eb7220a2447c5b3d208d7ef0a76c61a17a5b21da
    pdal = prev.pdal.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        (final.fetchpatch {
          name = "pdal-gdal-3.13-cslconstlist.patch";
          url = "https://github.com/PDAL/PDAL/commit/eb7220a2447c5b3d208d7ef0a76c61a17a5b21da.patch";
          hash = "sha256-WJ7PeCkSl+S+qURa1X3Z6D6LiPpvIXWmEap4XcYq9bk=";
        })
      ];
    });
  })

]
