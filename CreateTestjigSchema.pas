/----------------------------------------------------------
// Import Elrpint testjig pcb from gerber files
// (c)Jan Kåre Vatne 2022, jkvatne@online.no
// MIT Licence, free to use and modify.
//----------------------------------------------------------


// Constants for configuration of generator
// Change them as required
const
    // Library path must be set to the library containing
    LibraryFile = 'C:\doc\altiumlib\Mechanical.SchLib';
    // To avoid entering the file name, set DefaultFileName til the path/name of your gerber file.
    DefaultFileName = '';
    // Library component names
    ConnectorName = 'M2x32';

// Global variables
var
    Board     : IPCB_Board;
    Schema    : ISCH_doc;
    WorkSpace : IWorkSpace;
    tpno      : integer;

procedure PlaceConnectorNet(xpos:integer; ypos:integer; name:string);
var SchWire:ISch_Wire; SchNetlabel : ISch_Netlabel;
begin
    SchWire := SchServer.SchObjectFactory(eWire,eCreate_GlobalCopy);
    SchWire.Location := Point(MilsToCoord(xpos), MilsToCoord(ypos));
    SchWire.VerticesCount := 2;
    SchWire.Vertex[1] := Point(MilsToCoord(xpos), MilsToCoord(ypos));
    SchWire.Vertex[2] := Point(MilsToCoord(xpos+800), MilsToCoord(ypos));
    Schema.RegisterSchObjectInContainer(SchWire);
    SchNetlabel := SchServer.SchObjectFactory(eNetlabel,eCreate_GlobalCopy);
    SchNetlabel.Location    := Point(MilsToCoord(xpos), MilsToCoord(ypos));
    SchNetlabel.Orientation := eRotate0;
    SchNetlabel.Text        := name;
    Schema.RegisterSchObjectInContainer(SchNetlabel);
end;

procedure PlaceSchTestPin(xpos, ypos: double; Designator: string; CompName: string; NetName: string);
var SchNetlabel : ISch_Netlabel;  ok : boolen; s:string;  SchWire:ISch_Wire;
begin
    s := 'Orientation=0';
    s := s + '|Location.X='+IntToStr(MilsToCoord(xpos));
    s := s + '|Location.Y='+IntToStr(MilsToCoord(ypos));
    s := s + '|designator='+Designator;
    tpno:=tpno+1;
    IntegratedLibraryManager.PlaceLibraryComponent(CompName, LibraryFile, s);

    SchNetlabel := SchServer.SchObjectFactory(eNetlabel,eCreate_GlobalCopy);
    SchNetlabel.Location    := Point(MilsToCoord(xpos+300), MilsToCoord(ypos));
    SchNetlabel.Orientation := eRotate0;
    SchNetlabel.Text        := NetName;
    Schema.RegisterSchObjectInContainer(SchNetlabel);

    SchWire := SchServer.SchObjectFactory(eWire,eCreate_GlobalCopy);
    SchWire.Location := Point(MilsToCoord(xpos), MilsToCoord(ypos));
    SchWire.VerticesCount := 2;
    SchWire.Vertex[1] := Point(MilsToCoord(xpos+100), MilsToCoord(ypos));
    SchWire.Vertex[2] := Point(MilsToCoord(xpos+800), MilsToCoord(ypos));
    Schema.RegisterSchObjectInContainer(SchWire);

    PlaceConnectorNet(12200, 10200-tpno*100, NetName);

end;

// Place connector M2x32 on schematic
procedure PlaceConnector(xpos:integer; ypos:integer);
var s:string;
begin
    s:= 'Orientation=0|Location.X='+IntToStr(MilsToCoord(xpos))+'|Location.Y='
        +IntToStr(MilsToCoord(ypos))+'|designator=X1';
    IntegratedLibraryManager.PlaceLibraryComponent(
        ConnectorName,
        LibraryFile,
        s);
end;

// Create a schematic with all test pins, with correct net names.
procedure CreateTestjigSch(InputFile: TextFile);
var name, line, NetName, HoleDia, PinType, Designator: string; xpos, ypos: integer; i, j:integer;
begin
    tpno:=1;
    // Initialize the robots in Schematic editor.
    //SchServer.ProcessControl.PreProcess(Schema, '');
    //PlaceConnector(13000, 10000);
    xpos:=800; ypos:=800;
    name:='-';
    Reset(InputFile);

    while not EOF(InputFile) do begin
        Readln(InputFile, line);
        if copy(line,1,6)='PinItm' then begin
            i := pos('=',line    );
            line := copy(line, i+1, 9999);
            i := pos('|',line);
            // First fieeld is net name
            NetName := copy(line, 1, i-1);
            // Unused field, allways N
            line := copy(line, i+1, 9999);
            i := pos('|',line);
            // X posision
            line := copy(line, i+1, 9999);
            i := pos('|',line);
            //xpos := strtoint(copy(line, 1, i-1));
            // Y posision
            line := copy(line, i+1, 9999);
            i := pos('|',line);
            //ypos := strtoint(copy(line, 1, i-1));
            // Hole diameter
            line := copy(line, i+1, 9999);
            i := pos('|',line);
            HoleDia := strtoint(copy(line, 1, i-1));
            // Connector pin number - not used now
            line := copy(line, i+1, 9999);
            i := pos('|',line);
            // Pin type (Q,B etc.)
            line := copy(line, i+1, 9999);
            i := pos('|',line);
            PinType := copy(line, 1, i-1);
            line := copy(line, i+1, 9999);
            // Last item is designator (TPnn)
            Designator:=line;
            if HoleDia=1350000 then begin
                PlaceSchTestPin(xpos, ypos, Designator, 'R75'+PinType, NetName);
            end else if HoleDia=1700000 then begin
                PlaceSchTestPin(xpos, ypos, Designator, 'R100'+PinType, NetName);
            end;
            if HoleDia<5000000 then begin
               ypos := ypos+300;
               if ypos>10000 then begin
                  xpos:=xpos+1200;
                  ypos:=800;
               end;
            end;
        end;
    end;
    SchServer.GetCurrentSchDocument.GraphicallyInvalidate;
end;


// Main procedure to run.
procedure Run;
var Dialog: TOpenDialog; InputFile: TextFile;
begin
    Dialog:=TOpenDialog.Create(nil);
    Dialog.Filename:=DefaultFileName;
    if (DefaultFileName<>'') or Dialog.Execute then begin
        // Create a new pcb document
        WorkSpace := GetWorkSpace;
        If WorkSpace = Nil Then Exit;
        Client.StartServer('SCH');
        If SchServer = Nil Then Exit;
        CreateNewDocumentFromDocumentKind('SCH');
        Schema := SchServer.GetCurrentSchDocument;
        AssignFile(InputFile, Dialog.Filename);
        try
            SchServer.ProcessControl.PreProcess(Schema, '');
            CreateTestjigSch(InputFile);
        finally
            SchServer.ProcessControl.PostProcess(Schema, '');
        end;
    end;
end;


