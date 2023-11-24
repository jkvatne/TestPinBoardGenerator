//----------------------------------------------------------
// Import Elprint testjig pcb from Maccaos mtt file
// (c)Jan Kåre Vatne 2022, jkvatne@online.no
// MIT Licence, free to use and modify.
//----------------------------------------------------------


// Constants for configuration of generator
// Change them as required
const
    // To avoid entering the file name, you can set DefaultFileName to the path/name of your mtt file.
    // If no name is given, a File select dialogue will be shown
    DefaultFileName = '';
    // Offsets are used only to place the board a bit from the absolute origin. Could be smaller, but
    // zero is not possible because Altium does not allow negative absolute coordinates.
    OffsetX = 10.0;
    OffsetY = 10.0;
    // Board has rounded corners, and rounded inner corner
    ArcRadi = 2.0;
    // The top extends this length
    TopExtra = 25.0;
    // The size of the "shoulders" of the board
    TopInset = 35.0;
    // Guides are normaly not placed on test circuit pcb. Set to true if you want it.
    PlaceGuides = false;
    // Relief width for the pads
    ReliefWidth = 0.254;
    // Solder mask expasion for the pads
    SolderMaskExpansion = 0.01;

// Global variables. Only the board itself is global to avoid passing it to all functions.
var
    Board     : IPCB_Board;

// Make a new pcb arc
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

// Delete any outline on the given layer if it exists
// Also deletes any dimensions because they usualy are connected to the outline.
procedure DeleteExistingOutline(layer: TLayer);
var Iterator : IPCB_BoardIterator; var Track : IPCB_Track;  Arc: IPCB_Arc; Dim: IPCB_Dimension; s:string;
begin
    if Board=nil then begin
       abort;
    end;
    s := Board.FileName;
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
    Iterator.AddFilter_ObjectSet(MkSet(eDimensionObject));
    Dim := Iterator.FirstPCBObject;
    while Dim<>nil do begin
        Board.RemovePCBObject(Dim);
        Dim := Iterator.NextPCBObject;
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
procedure GenerateOutline(var Board : IPCB_Board; width, height: double);
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

// Find size
Procedure FindSize(InputFile: TextFile; var SizeX: double; var SizeY: double);
var line: string;
begin
    SizeX := -1;
    SizeY := -1;
    Reset(InputFile);
    while not EOF(InputFile) do begin
        Readln(InputFile, line);
        if (line=Null) or (length(line)<6) then begin
            // Ignore blank lines
        end else if copy(line,1,5)='SizeX' then begin
            SizeX := strtofloat(copy(line,7,999));
        end else if copy(line,1,5)='SizeY' then begin
            SizeY := strtofloat(copy(line,7,999));
        end;
    end;
end;


// Place a pad on the pcb. All dimensions in millimeters.
Function NewPad(AX,AY : double; ATopSize, AHoleSize : double; ALayer : TLayer; AName : string; round: boolean) : IPCB_Pad;
Var
    Pad        : IPCB_Pad;
    PadCache : TPadCache;
Begin
    Result := Nil;
    Pad := PcbServer.PCBObjectFactory(ePadObject,eNoDimension,eCreate_Default);
    If Pad = Nil Then Exit;

    Pad.X        := MMsToCoord(AX);
    Pad.Y        := MMsToCoord(AY);
    Pad.TopXSize := MMsToCoord(ATopSize);
    Pad.TopYSize := MMsToCoord(ATopSize);
    if round then begin
        Pad.TopShape := eRounded;
    end else begin
        Pad.TopShape := eRectangular;
    end;
    Pad.HoleSize := MMsToCoord(AHoleSize);
    Pad.Layer    := ALayer;
    Pad.Name     := AName;

    // Setup a pad cache
    Padcache := Pad.GetState_Cache;
    Padcache.ReliefAirGap              := MMsToCoord(ReliefWidth);
    Padcache.PowerPlaneReliefExpansion := MMsToCoord(ReliefWidth);
    Padcache.PowerPlaneClearance       := MMsToCoord(ReliefWidth);
    Padcache.ReliefConductorWidth      := MMsToCoord(ReliefWidth);
    Padcache.SolderMaskExpansion       := MMsToCoord(SolderMaskExpansion);
    Padcache.SolderMaskExpansionValid  := eCacheManual;
    Padcache.PasteMaskExpansion        := 0;
    Padcache.PasteMaskExpansionValid   := eCacheManual;

    // Assign the new pad cache to the pad
    Pad.SetState_Cache(Padcache);
    Result := Pad;
End;


// Place a test pin on pcb. All dimensions im millimeters.
procedure PlaceTestPin(x,y : double; NetName:string, HoleDiameter: double);
var
    Comp : IPCB_Component;
    Pad : IPCB_Pad;
    Net : IPCB_Net;
    Iterator : IPCB_BoardIterator;
begin
    Comp := PCBServer.PCBObjectFactory(eComponentObject, eNoDimension, eCreate_Default);
    If Comp = Nil Then Exit;
    // Create a pad
    if HoleDiameter <= 1.4 then begin
        Pad := NewPad(0,0, 1.79, 1.2, eMultiLayer, '1', true);
    end else if HoleDiameter >=4.0 then begin
        Pad := NewPad(0,0, 5.5, 3.2, eMultiLayer, '0', true);
    end else begin
        Pad := NewPad(0,0, 2.2, 1.2, eMultiLayer, '1', true);
    end;
    Comp.AddPCBObject(Pad);
    // Add net name if undefined
    if (NetName<>'') and (HoleDiameter<4.9) then begin
        Iterator := Board.BoardIterator_Create;
        Iterator.AddFilter_ObjectSet(MkSet(eNetObject));
        Net := Iterator.FirstPCBObject;
        while Net<>nil do begin
           if Net.Name=NetName then begin
               break;
           end;
           Net := Iterator.NextPCBObject;
        end;
        if Net=nil then begin
            Net := PCBServer.PCBObjectFactory(eNetObject, eNoDimension, eCreate_Default);
            Net.Name :=NetName;
        end;
        Board.AddPCBObject(Net);
        //PCBServer.SendMessageToRobots(Board.I_ObjectAddress,c_Broadcast,PCBM_BoardRegisteration,NewNet.I_ObjectAddress);
    end;

    // Set net name to pad
    Pad.net:=Net;

    // Set the reference point of the Component
    Comp.X         := MmsToCoord(x);
    Comp.Y         := MmsToCoord(y);
    Comp.Layer     := eTopLayer;

    // Make the designator text visible;
    Comp.NameOn         := True;
    Comp.Name.Text      := NetName;
    Comp.Name.Size      := MmsToCoord(0.9);
    Comp.Name.Rotation  := 270;
    Comp.Name.Width     := MmsToCoord(0.15);
    Comp.Name.FontName  := 'Sans Serif';
    Comp.Name.XLocation := MmsToCoord(x - 0.4);
    if HoleDiameter <= 1.4 then begin
        Comp.Name.YLocation := MmsToCoord(y - 1.1);
    end else begin
        Comp.Name.YLocation := MmsToCoord(y - 1.3);
    end;

    // Make the comment text NOT visible;
    Comp.CommentOn         := False;
    Comp.Comment.Text      := '';
    Comp.Comment.XLocation := MmsToCoord(x+1.0);
    Comp.Comment.YLocation := MmsToCoord(y+2);

    Board.AddPCBObject(Comp);
    //PCBServer.SendMessageToRobots(Board.I_ObjectAddress,c_Broadcast,PCBM_BoardRegisteration,Comp.I_ObjectAddress);
End;

Procedure CreateTestpoints(InputFile: TextFile);
var
    SizeX, SizeY: double; found:boolean;
    i, j, n, GuideNo, DistNo:  Integer;
    NetName, Designator, Line, Xpos, Ypos, HoleDia, PinType : string;
    Iterator : IPCB_BoardIterator;
    Comp: IPCB_Component;
begin
    n:=0;
    GuideNo := 0;
    DistNo :=0;
    Reset(InputFile);
    while not EOF(InputFile) do begin
        Readln(InputFile, line);
        if (line=Null) or (length(line)<6) then begin
          // Ignore blank lines
        end else if copy(line,1,5)='SizeX' then begin
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
            // Pin type (A,B etc.)
            PinType := copy(line, 1, i-1);
            line := copy(line, i+1, 9999);
            // Last item is designator (TPnn)
            Designator:=line;
            // If designator not given, make one
            if (NetName<>'Distance') and (NetName<>'Guide') and (NetName<>'Support') then begin
               if (Designator='') then begin
                   Designator:='TP'+inttostr(n);
                   n := n+1;
               end;
            end;
            if HoleDia='1350000' then begin
              PinType:='R75'+PinType;
            end else if HoleDia='1700000' then begin
              PinType:='R100'+PinType;
            end else if HoleDia='5000000' then begin
              if NetName='Distance' then begin
                DistNo := DistNo + 1;
                PinType:='Dist';
                Designator:='DIST'+inttostr(DistNo);
              end else if NetName='Support' then begin
                DistNo := DistNo + 1;
                PinType:='Dist';
                Designator:='DIST'+inttostr(DistNo);
              end else if NetName='Guide' then begin
                if not PlaceGuides then continue;
                PinType:='Guide';
                GuideNo := GuideNo + 1;
                Designator:='GUIDE'+inttostr(GuideNo);
              end;
            end else begin
              ShowMessage('Unknown pin type with hole diameter '+HoleDia+' um');
              PinType:='Unknown';
              continue;
            end;

            // Search for existing testpoint
            Iterator := Board.BoardIterator_Create;
            Iterator.AddFilter_ObjectSet(MkSet(eComponentObject));
            Comp := Iterator.FirstPCBObject;
            found:=false;
            while Comp<>nil do begin
                if (Comp.Name.Text=Designator)  then begin
                   PCBServer.SendMessageToRobots(Comp.I_ObjectAddress, c_Broadcast, PCBM_BeginModify ,c_NoEventData);
                   Comp.X := MmsToCoord(StrToInt(xpos)/1e6+SizeX/2+OffsetX);
                   Comp.Y := MmsToCoord(StrToInt(ypos)/1e6+SizeY-67.0+OffsetY);
                   Comp.GraphicallyInvalidate;
                   PCBServer.SendMessageToRobots(Comp.I_ObjectAddress, c_Broadcast, PCBM_EndModify , c_NoEventData);
                   found:=true;
                   break;
                end;
                Comp:=Iterator.NextPCBObject;
            end;

            // If not existing testpoint was found, create a new
            if not found then begin
                PCBServer.PreProcess;
                PlaceTestPin(
                    StrToInt(xpos)/1e6+SizeX/2+OffsetX,
                    StrToInt(ypos)/1e6+SizeY-67.0+OffsetY,
                    Designator,
                    StrToInt(HoleDia)/1e6);
                PCBServer.PostProcess;
            end;
            Board.BoardIterator_Destroy(Iterator);
        end;
    end;
    DeleteExistingOutline(eMechanical1);
    GenerateOutline(Board, SizeX, SizeY);
end;

// Main procedure to run.
procedure Run;
var
    Dialog: TOpenDialog;
    InputFile: TextFile;
    SizeX: double;
    SizeY: double;
begin
    // Normally the script should be run while a existing PCB board is in focus
    Board := PCBServer.GetCurrentPCBBoard;
    // If there was no board, we create a new one
    if Board = nil then begin
       Board := CreateNewDocumentFromDocumentKind('PCB');
       // Need this to get a correct type of Board
       Board := PCBServer.GetCurrentPCBBoard;
    end;
    if Board=nil then begin
       ShowError('Could not create a new PCB document');
       exit;
    end;
    // Get mtt file name from user unless given in DefaultFileName
    Dialog:=TOpenDialog.Create(nil);
    Dialog.Filename:=DefaultFileName;
    Dialog.Title:='Select mtt file for pcb generation';
    Dialog.Filter:='Macaos files (*.mtt)|*.mtt' ;
    if (DefaultFileName<>'') or Dialog.Execute then begin
        if sametext(AnsiRightStr(Dialog.Filename,3),'mtt') then begin
            AssignFile(InputFile, Dialog.Filename);
            PCBServer.PreProcess;
            try
                FindSize(InputFile, SizeX, SizeY);
                if (SizeX<=0) or (SizeY<=0) then begin
                    ShowError('Size not found in the mtt .');
                    exit;
                end;
                DeleteExistingOutline(eMechanical1);
                GenerateOutline(Board, SizeX, SizeY);
                CreateTestpoints(InputFile);
            finally
                PCBServer.PostProcess;
                CloseFile(InputFile);
            end;
            // Refresh PCB screen
            Client.CommandLauncher.LaunchCommand('PCB:Zoom', 'Action=Redraw' , 255, Client.CurrentView);
            ShowMessage('Generated outline and testpoints!');
        end else begin
            ShowError('File must be a *.mtt file from Macaos, generated by the save command.');
        end;
    end;
end;



