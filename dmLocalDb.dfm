object dmLocDB: TdmLocDB
  OnCreate = DataModuleCreate
  Height = 480
  Width = 640
  object FDPhysSQLiteDriverLink1: TFDPhysSQLiteDriverLink
    Left = 76
    Top = 68
  end
  object FDConnection1: TFDConnection
    Left = 76
    Top = 8
  end
  object FDQuery1: TFDQuery
    Connection = FDConnection1
    Left = 76
    Top = 132
  end
  object FDGUIxWaitCursor1: TFDGUIxWaitCursor
    Provider = 'FMX'
    Left = 76
    Top = 200
  end
end
