(* piling everything into the DNAnexus module *)

include DX

module type DataObject = sig
  include DXDataObject.S

module Record = struct
  include DXDataObject.Record

module File = struct
  include DXDataObject.File

module GTable = struct
  include DXDataObject.GTable
