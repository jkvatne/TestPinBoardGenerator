//----------------------------------------------------------
// Import Elrpint testjig pcb from gerber files
// (c)Jan Kåre Vatne 2022, jkvatne@online.no
// MIT Licence, free to use and modify.
//----------------------------------------------------------


// Constants for configuration of generator
// Change them as required
const
    // To avoid entering the file name, set DefaultFileName til the path/name of your gerber file.
    DefaultFileName = '';
    // Offsets are used only to place the board a bit from the absolute origin. Could be smaller, but
    // zero is not convenient because nothing can have negative absolute coordinates.
    OffsetX = 100.0;
    OffsetY = 100.0;
    // Board has rounded corners, and rounded inner corner
    ArcRadi = 2.0;
    // The top extends this length
    TopExtra = 25.0;
    // The size of the "shoulders" of the board
    TopInset = 35.0;

// Global variables. Only the board itself is global to avoid passing it to all functions.
var
    Board     : IPCB_Board;


function NewArc(x,y:double; radius:double; width:double; startangle, endangle: double): IPCB_Arc;
begin
    result := PCBServer.PCBObjectFactory(eArcObject, eNoDimension, eCreate_Default);
    PCBServer.SendMessageToRobots(result.I_ObjectAddress ,c_Broadcast, PCBM_BeginModify , c_NoEventData);
    result.XCenter    := MMsToCoord(x+OffsetX);
    result.YCenter    := MMsToCoord(y+OffsetY);
    result.Layer      := eMechanical1;
    result.LineWidth  := MMsToCoord(width);
    result.Radius     := MMsToCoord(radius);
    result.StartAngle := startangle;
    result.EndAngle   := endangle;
    PCBServer.SendMessageToRobots(result.I_ObjectAddress, c_Broadcast, PCBM_EndModify, c_NoEventData);
end;

procedure DeleteExistingOutline(layer: TLayer);
var Iterator : IPCB_BoardIterator; var Track : IPCB_Track;  Arc: IPCB_Arc;
begin
    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eTrackObject));
    Track := Iterator.FirstPCBObject;
    while Track<>nil do begin
        if Track.Layer = layer then begin
            Board.RemovePCBObject(Track);
        end;
        Track := Iterator.NextPCBObject;
    end;
    Iterator.AddFilter_ObjectSet(MkSet(eArcObject));
    Arc := Iterator.FirstPCBObject;
    while Arc<>nil do begin
        if Arc.Layer = layer then begin
            Board.RemovePCBObject(Arc);
        end;
        Arc := Iterator.NextPCBObject;
    end;
    Board.BoardIterator_Destroy(Iterator);
end;

// Place a track on the pcb. All dimensions in millimeters.
function NewTrack(x1, y1, x2, y2 : double; width : double; ALayer : TLayer) : IPCB_Track;
var
   T : IPCB_Track;
begin
    T             := PCBServer.PCBObjectFactory(eTrackObject,eNoDimension,eCreate_Default);
    PCBServer.SendMessageToRobots(T.I_ObjectAddress ,c_Broadcast, PCBM_BeginModify , c_NoEventData);
    T.X1          := MMsToCoord(x1+OffsetX);
    T.Y1          := MMsToCoord(y1+OffsetY);
    T.X2          := MMsToCoord(x2+OffsetX);
    T.Y2          := MMsToCoord(y2+OffsetY);
    T.Layer       := ALayer;
    T.Width       := MMsToCoord(width);
    T.Selected    := true;
    PCBServer.SendMessageToRobots(T.I_ObjectAddress, c_Broadcast, PCBM_EndModify, c_NoEventData);
    Result := T;
end;

// Generate outline
// The tracks and arcs are placed with origo in lower left corner
procedure GenerateOutline(width, height: double);
var Track : IPCB_Track;  Arc: IPCB_Arc; ok:boolean;
begin
    // Bottom line
    Track := NewTrack(ArcRadi, 0.0, width-ArcRadi, 0.0, 0.15, eMechanical1);
    Board.AddPCBObject(Track);
    PCBServer.SendMessageToRobots(Track.I_ObjectAddress, c_Broadcast, PCBM_BoardRegisteration ,c_NoEventData);
    Track.selected := true;
    // Left edge
    Track := NewTrack(0.0, ArcRadi, 0.0, height-TopExtra-ArcRadi, 0.15, eMechanical1);
    Board.AddPCBObject(Track);
    Track.selected := true;
    // Right edge
    Track := NewTrack(width, ArcRadi, width, height-TopExtra-ArcRadi, 0.15, eMechanical1);
    Board.AddPCBObject(Track);
    Track.selected := true;
    // Left top vertical
    Track := NewTrack(TopInset, height-TopExtra+ArcRadi, TopInset, height-ArcRadi, 0.15, eMechanical1);
    Board.AddPCBObject(Track);
    Track.selected := true;
    // Right top vertical
    Track := NewTrack(width-TopInset, height-ArcRadi, width-TopInset, height-TopExtra+ArcRadi, 0.15, eMechanical1);
    Board.AddPCBObject(Track);
    Track.selected := true;
    // Top center horizontal
    Track := NewTrack(TopInset+ArcRadi, height, width-TopInset-ArcRadi, height, 0.15, eMechanical1);
    Board.AddPCBObject(Track);
    Track.selected := true;
    // Left top horizontal
    Track := NewTrack(ArcRadi, height-TopExtra, TopInset-ArcRadi, height-TopExtra, 0.15, eMechanical1);
    Board.AddPCBObject(Track);
    Track.selected := true;
    // Right top horizontal
    Track := NewTrack(width-TopInset+ArcRadi, height-TopExtra, width-ArcRadi, height-TopExtra, 0.15, eMechanical1);
    Board.AddPCBObject(Track);
    Track.selected := true;
    // Bottom arcs
    Arc := NewArc(ArcRadi, ArcRadi, ArcRadi, 0.15, 180, 270);
    Board.AddPCBObject(Arc);
    Arc.selected := true;
    Arc := NewArc(width-ArcRadi, ArcRadi, ArcRadi, 0.15, 270, 360);
    Board.AddPCBObject(Arc);
    Arc.selected := true;
    // Top arcs
    Arc := NewArc(ArcRadi, height-TopExtra-ArcRadi, ArcRadi, 0.15,  90, 180);
    Board.AddPCBObject(Arc);
    Arc.selected := true;
    Arc := NewArc(width-ArcRadi, height-TopExtra-ArcRadi, ArcRadi, 0.15,   0,  90);
    Board.AddPCBObject(Arc);
    Arc.selected := true;
    Arc := NewArc(TopInset+ArcRadi, height-ArcRadi,  ArcRadi, 0.15,  90, 180);
    Board.AddPCBObject(Arc);
    Arc.selected := true;
    Arc := NewArc(width-TopInset-ArcRadi, height-ArcRadi,  ArcRadi, 0.15,   0,  90);
    Board.AddPCBObject(Arc);
    Arc.selected := true;
    // Top inner corners
    Arc := NewArc(TopInset-ArcRadi, height-TopExtra+ArcRadi, ArcRadi, 0.15, 270, 360);
    Board.AddPCBObject(Arc);
    Arc.selected := true;
    Arc := NewArc(width-TopInset+ArcRadi, height-TopExtra+ArcRadi, ArcRadi, 0.15, 180, 270);
    Board.AddPCBObject(Arc);
    Arc.selected := true;

    // Create outline from selected tracks
    ResetParameters;
    AddStringParameter('Mode', 'BOARDOUTLINE_FROM_SEL_PRIMS');
    ok :=RunProcess('PCB:PlaceBoardOutline');

    // Deselect border
    ResetParameters;
    AddStringParameter('Scope', 'All');
    RunProcess('PCB:DeSelect');
end;

Procedure ParseMttFile(InputFile: TextFile);
var
    SizeX, SizeY: double;
    i, j, n, GuideNo:  Integer;
    NetName, Designator, Line, Xpos, Ypos, HoleDia, PinType : string;
    Iterator : IPCB_BoardIterator;
    Comp: IPCB_Component;
begin
    n:=0;
    GuideNo := 0;
    Reset(InputFile);
    while not EOF(InputFile) do begin
        Readln(InputFile, line);
        if copy(line,1,5)='SizeX' then begin
            SizeX := strtofloat(copy(line,7,999));
        end else if copy(line,1,5)='SizeY' then begin
            SizeY := strtofloat(copy(line,7,999));
        end else if copy(line,1,6)='PinItm' then begin
            i := pos('=',line);
            line := copy(line, i+1, 9999);
            i := pos('|',line);
            NetName := copy(line, 1, i-1);
            line := copy(line, i+1, 9999);
            i := pos('|',line);
            // Unused field, allways N
            line := copy(line, i+1, 9999);
            i := pos('|',line);
            xpos := copy(line, 1, i-1);
            line := copy(line, i+1, 9999);
            i := pos('|',line);
            ypos := copy(line, 1, i-1);
            line := copy(line, i+1, 9999);
            i := pos('|',line);
            HoleDia := copy(line, 1, i-1);
            line := copy(line, i+1, 9999);
            i := pos('|',line);
            // Connector pin number - not used now
            line := copy(line, i+1, 9999);
            i := pos('|',line);
            // Pin type (Q,B etc.)
            PinType := copy(line, 1, i-1);
            line := copy(line, i+1, 9999);
            // Last item is designator (TPnn)
            Designator:=line;
            // If designator not given, make one
            if Designator='' then begin
                Designator:='TP'+inttostr(n);
            end;
            if HoleDia='1350000' then begin
              PinType:='R75'+PinType;
            end else if HoleDia='1700000' then begin
              PinType:='R100'+PinType;
            end else if HoleDia='5000000' then begin
              GuideNo := GuideNo + 1;
              PinType:='Guide';
              Designator:='GUIDE'+inttostr(GuideNo);
            end else begin
              PinType:='Unknown';
            end;

            Iterator := Board.BoardIterator_Create;
            Iterator.AddFilter_ObjectSet(MkSet(eComponentObject));
            Comp := Iterator.FirstPCBObject;
            while Comp<>nil do begin
                if (Comp.Name.Text=Designator)  then begin
                   PCBServer.SendMessageToRobots(Comp.I_ObjectAddress, c_Broadcast, PCBM_BeginModify ,c_NoEventData);
                   Comp.X := MmsToCoord(StrToInt(xpos)/1e6+SizeX/2+OffsetX);
                   Comp.Y := MmsToCoord(StrToInt(ypos)/1e6+SizeY-67.0+OffsetY);
                   Comp.GraphicallyInvalidate;
                   PCBServer.SendMessageToRobots(Comp.I_ObjectAddress, c_Broadcast, PCBM_EndModify , c_NoEventData);
                   break;
                end;
                Comp:=Iterator.NextPCBObject;
            end;
            Board.BoardIterator_Destroy(Iterator);
            n:=n+1;
        end;
    end;
    DeleteExistingOutline(eMechanical1);
    GenerateOutline(SizeX, SizeY);
end;

// Main procedure to run.
procedure Run;
var
    Dialog: TOpenDialog;
    InputFile: TextFile;
begin
    Dialog:=TOpenDialog.Create(nil);
    Dialog.Filename:=DefaultFileName;
    Dialog.Title:='Select mtt file';
    Dialog.Filter:='Macaos files (*.mtt)|*.mtt'
    if (DefaultFileName<>'') or Dialog.Execute then begin
        AssignFile(InputFile, Dialog.Filename);
        // Check if PCB document exists
        Board := PCBServer.GetCurrentPCBBoard;
        if Board = nil then begin
            ShowError('Current document is not PCB document');
        end else if AnsiRightStr(Dialog.Filename,3)='mtt' then begin
            PCBServer.PreProcess;
            ParseMttFile(InputFile);
            PCBServer.PostProcess;
            // Refresh PCB screen
            Client.CommandLauncher.LaunchCommand('PCB:Zoom', 'Action=Redraw' , 255, Client.CurrentView);
            ShowMessage('Generated outline and moved testpoints!');
        end else begin
            ShowError('File must be a *.mtt file from Macaos, generated by the save command.');
        end;
    end;
end;

