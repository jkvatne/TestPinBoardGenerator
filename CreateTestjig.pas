//----------------------------------------------------------
// Import Elrpint testjig pcb from gerber files
// (c)Jan Kåre Vatne 2022, jkvatne@online.no
// MIT Licence, free to use and modify.
//----------------------------------------------------------


// Constants for configuration of generator
// Change them as required
const
    // Set true to create new file. When false it will update current pcb/schema
    CreateNewPcb = true;
    CreateNewSch = true;
    // Relief width and air gap. The default here is 10mils and will be ok for most prosjects
    ReliefWidth = 0.254;
    // Solder mas expansion. Here it is 0.01mm.
    SolderMaskExpansion = 0.01;
    // Library path must be set to the library containing
    LibraryFile = 'C:\doc\altiumlib\Mechanical.SchLib';
    // To avoid entering the file name, set DefaultFileName til the path/name of your gerber file.
    DefaultFileName = 'C:\doc\RollsRoyce\RRLC2-testjig\input\RRLC2TJ-v6.mtt';
    // The pcb hole for the needle holders. Typicaly they have 1mm dia round pins for all needle sizes.
    HoleDiameter = 1.1;
    // For pins with 2mm spacing, and 1.1mm holes we use 0.25mm anular giving giving 0.4mm clearance.
    AnularRing   = 0.2;
    // Library component names
    ConnectorName = 'M2x32';
    TestPinName = 'TP-SCT';

// Global variables
var
    Board     : IPCB_Board;
    Schema    : ISCH_doc;
    WorkSpace : IWorkSpace;
    // Size and offset of board. Must be global.
    OffsetX, OffsetY : double;
    MaxX, MaxY :  double;

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


// Place a track on the pcb. All dimensions in millimeters.
Function NewTrack(x1, y1, x2, y2 : double; width : double; ALayer : TLayer) : IPCB_Track;
Var
   T : IPCB_Track;
Begin
    T             := PCBServer.PCBObjectFactory(eTrackObject,eNoDimension,eCreate_Default);
    T.X1          := MMsToCoord(x1);
    T.Y1          := MMsToCoord(y1);
    T.X2          := MMsToCoord(x2);
    T.Y2          := MMsToCoord(y2);
    T.Layer       := ALayer;
    T.Width       := MMsToCoord(width);
    T.Selected    := true;
    Result := T;
End;

procedure SetupPadCache(Pad: IPCB_Pad);
begin
    // Setup a pad cache
    Padcache := P.GetState_Cache;
    Padcache.ReliefAirGap := MilsToCoord(11);
    Padcache.PowerPlaneReliefExpansion := MilsToCoord(10);
    Padcache.PowerPlaneClearance       := MilsToCoord(10);
    Padcache.ReliefConductorWidth      := MilsToCoord(10);
    Padcache.SolderMaskExpansion       := MilsToCoord(10);
    Padcache.SolderMaskExpansionValid  := eCacheManual;
    Padcache.PasteMaskExpansion        := MilsToCoord(10);
    Padcache.PasteMaskExpansionValid   := eCacheManual;
    // Assign the new pad cache to the pad
    Pad.SetState_Cache(Padcache);
end;

function NewNet(NetName:string): IPCB_Net;
var NewNet : IPCB_Net;
    Iterator : IPCB_BoardIterator;
begin
    Iterator := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eNetObject));
    NewNet := Iterator.FirstPCBObject;
    while Newnet<>nil do begin
       if NewNet.Name=NetName then begin
           break;
       end;
       NewNet := Iterator.NextPCBObject;
    end;
    // Create new net only if it does not exist
    if NewNet=nil then begin
        NewNet := PCBServer.PCBObjectFactory(eNetObject, eNoDimension, eCreate_Default);
        NewNet.Name :=NetName;
    end;
    Board.AddPCBObject(NewNet);
    result :=NewNet;
end;

Procedure PlaceTestPinComp(x,y : double; Designator, Comment, NetName:string, PinDia: double);
Var
    Comp : IPCB_Component;
    Pad  : IPCB_Pad;
Begin
    Comp := PCBServer.PCBObjectFactory(eComponentObject, eNoDimension, eCreate_Default);
    If Comp = Nil Then Exit;

    if pinDia>=5.0 then begin
        Pad:=NewPad(0,0, pinDia+0.5, pinDia, eMultiLayer, '0', true);
    end else begin
        Pad:=NewPad(0,0, HoleDiameter+2*AnularRing, HoleDiameter, eMultiLayer, '1', true);
    end;
    Pad.net:=NewNet(NetName);
    Comp.AddPCBObject(Pad);

    // Set the reference point of the Component
    Comp.X         := MmsToCoord(x);
    Comp.Y         := MmsToCoord(y);
    Comp.Layer     := eTopLayer;

    // Make the designator text visible;
    Comp.NameOn         := pinDia<5.0;
    Comp.Name.Text      := Designator;
    Comp.Name.Size      := MmsToCoord(1.0);
    Comp.Name.Rotation  := 270;
    Comp.Name.XLocation := MmsToCoord(x - 0.4);
    Comp.Name.YLocation := MmsToCoord(y - HoleDiameter-AnularRing);

    // Make the comment text visible;
    Comp.CommentOn         := pinDia<5.0;
    Comp.Comment.Text      := Comment;
    Comp.Comment.Rotation  := 90;
    Comp.Comment.Size      := MmsToCoord(1.0);
    Comp.Comment.XLocation := MmsToCoord(x + 0.4);
    Comp.Comment.YLocation := MmsToCoord(y + HoleDiameter + AnularRing + 0.1);

    Board.AddPCBObject(Comp);
End;

// Place a test pin on pcb. All dimensions im millimeters.
Procedure PlaceTestPin(x,y : double; NetName:string, HoleDia: double);
Var
    Comp : IPCB_Component;
    Pad : IPCB_Pad;
    Net : IPCB_Net;
    Iterator : IPCB_BoardIterator;
Begin
    Comp := PCBServer.PCBObjectFactory(eComponentObject, eNoDimension, eCreate_Default);
    If Comp = Nil Then Exit;

    // Create a pad
    Pad := NewPad(0,0, HoleDiameter+2*AnularRing, HoleDiameter, eMultiLayer, '1', true);
    Comp.AddPCBObject(Pad);
    //PCBServer.SendMessageToRobots(Comp.I_ObjectAddress,c_Broadcast,PCBM_BoardRegisteration, NewPad.I_ObjectAddress);

    if NetName<>'' then begin
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

    Pad.net:=Net;

    // Set the reference point of the Component
    Comp.X         := MmsToCoord(x);
    Comp.Y         := MmsToCoord(y);
    Comp.Layer     := eTopLayer;

    // Make the designator text visible;
    Comp.NameOn         := True;
    Comp.Name.Text      := NetName;
    Comp.Name.Size      := MmsToCoord(1.0);
    Comp.Name.Rotation  := 270;
    Comp.Name.XLocation := MmsToCoord(x - 0.4);
    Comp.Name.YLocation := MmsToCoord(y - HoleDiameter-AnularRing);

    // Make the comment text NOT visible;
    Comp.CommentOn         := False;
    Comp.Comment.Text      := '';
    Comp.Comment.XLocation := MmsToCoord(x+1.0);
    Comp.Comment.YLocation := MmsToCoord(y+2);

    Board.AddPCBObject(Comp);
    //PCBServer.SendMessageToRobots(Board.I_ObjectAddress,c_Broadcast,PCBM_BoardRegisteration,Comp.I_ObjectAddress);
End;


procedure CalculateOffset(InputFile: TextFile);
var line string; i,j: integer; xpos,ypos: double;
begin
    MaxX := -99999.9;
    MaxY := -99999.9;
    Reset(InputFile);
    while not EOF(InputFile) do begin
        Readln(InputFile, line);
        if (copy(line[1],1,1)='X') then begin
            // This should be a D02 (move) or D01 (draw) command
            i := pos('Y',line);
            xpos:=strtoint(copy(line,2,i-2))/1e6;
            j:=pos('I',line);
            if j=0 then begin
               j := pos('D', line);
            end;
            ypos:=strtoint(copy(line, i+1, j-i-1))/1e6;
            if xpos<OffsetX then begin
                OffsetX:=xpos;
            end;
            if ypos<OffsetY then begin
                OffsetY:=ypos;
            end;
            if xpos>MaxX then begin
                MaxX := xpos;
            end;
            if ypos>MaxY then begin
                MaxY := Ypos;
            end;
        end;
    end;
    MaxX := MaxX-OffsetX;
    MaxY := MaxY-OffsetY;
    OffsetX := -OffsetX;
    OffsetY := -OffsetY;
end;

// Create a 2.54mm pich connector. nx x ny pins. All dimensions in millimeters
procedure CreateConnector(x,y: double; nx,ny:integer; dx,dy:double, designator, name: string);
var
    Comp : IPCB_Component;
    Pad : IPCB_Pad;
    i,j:integer;
begin
    Comp := PCBServer.PCBObjectFactory(eComponentObject, eNoDimension, eCreate_Default);
    If Comp = Nil Then Exit;

    // Create a pad
    for j:=1 to ny do begin
        for i:=1 to nx do begin
            Pad := NewPad((i-1)*dx, (j-1)*2.54, 1.8, 1.0, eMultiLayer, inttostr((i-1)*ny +j), (i<>1) or (j<>1));
            Comp.AddPCBObject(Pad);
        end;
    end;

    // Set the reference point of the Component
    Comp.X         := MmsToCoord(x);
    Comp.Y         := MmsToCoord(y);
    Comp.Layer     := eTopLayer;

    // Make the designator text visible;
    Comp.NameOn         := True;
    Comp.Name.Text      := designator;
    Comp.Name.Size      := MmsToCoord(1.0);
    Comp.Name.Rotation  := 0.0;
    Comp.Name.XLocation := MmsToCoord(x);
    Comp.Name.YLocation := MmsToCoord(y-2.2);

    // Make the comment text visible;
    Comp.CommentOn         := True;
    Comp.Comment.Text      := name;
    Comp.Comment.Size      := MmsToCoord(1.0);
    Comp.Comment.Rotation  := 0.0;
    Comp.Comment.XLocation := MmsToCoord(x+3.0);
    Comp.Comment.YLocation := MmsToCoord(y-2.2);

    Board.AddPCBObject(Comp);
    //PCBServer.SendMessageToRobots(Board.I_ObjectAddress,c_Broadcast,PCBM_BoardRegisteration,Comp.I_ObjectAddress);

end;

var pad13:integer;
var pad15:integer;
var diameters: array [100..115] of double;
var aperture:integer;

// Parse the gerber file and create pcb outline and testpoints. Also adds 64 pin connector.
procedure CreateTestjigPcb(InputFile: TextFile);
var i,j,k: integer; cmd, name, line: string;
    Track : IPCB_Track;  Arc: IPCB_Arc;
    ival,jval,dx,dy,xpos,ypos,width: double;
    LastX, Lasty: double; ok:boolean;
begin
    aperture := 0;
    width:=0.254;
    name:='-';
    Reset(InputFile);
    while not EOF(InputFile) do begin
        Readln(InputFile, line);
        if copy(line,1,4)='%ADD' then begin
            // Check for pin pads. Assume they are 1.3 or 1.5mm
            j:=pos('*',line);
            aperture:=strtoint(copy(line,5,3));
            diameters[aperture]:=strtofloat(copy(line,10,j-10));
        end else if copy(line,1,6)='%TO.N,' then begin
            // Save name
            i := pos('*',line);
            name := copy(line, 7, i-7);
        end else if line[1]='D' then begin
            aperture:=strtoint(copy(line,2,3));
        end else if (line[1}='X') and (name<>'-') and (diameters[aperture]>0.4) and (diameters[aperture]<2.6) then begin
            // Pin pad with hole given by diameters[aperture]
            i := pos('Y',line);
            xpos:=strtoint(copy(line,2,i-2))/1e6+OffsetX;
            j := pos('D', line);
            ypos:=strtoint(copy(line, i+1, j-i-1))/1e6+OffsetY;
            PlaceTestPin(xpos, ypos, name, diameters[aperture]);
            name:='';
        end else if (aperture=100) and (copy(line,1,1)='X') then begin
            // Outline drawing
            // This should be a D02 (move) or D01 (draw) command
            i := pos('Y',line);
            xpos:=strtoint(copy(line,2,i-2))/1e6+OffsetX;
            j:=pos('I',line);
            if j=0 then begin
               j := pos('D', line);
            end;
            ypos:=strtoint(copy(line, i+1, j-i-1))/1e6+OffsetY;
            cmd:=copy(line,length(line)-3,4);
            if (cmd='D01*') and (pos('I',line)=0) then begin
               Track := NewTrack(xpos, ypos, lastx, lasty, width, eMechanical1);
               Board.AddPCBObject(Track);
               Track.Selected:=true;
               //PCBServer.SendMessageToRobots(NewTrack.I_ObjectAddress,c_Broadcast,PCBM_BoardRegisteration,NewTrack.I_ObjectAddress);
            end else if (cmd='D01*') and (pos('I',line)<>0) then begin
               i:=pos('I',line);
               j:=pos('J',line);
               k:=pos('D',line);
               iVal := strtoint(copy(line,i+1,j-i-1))/1e6;
               jVal := strtoint(copy(line,j+1,k-j-1))/1e6;
               dx := xpos-lastx;
               dy := ypos-lasty;
               Arc := PCBServer.PCBObjectFactory(eArcObject, eNoDimension, eCreate_Default);
               Arc.XCenter    := MMsToCoord(lastx+ival);
               Arc.YCenter    := MMsToCoord(lasty+jval);
               Arc.Layer      := eMechanical1;
               Arc.LineWidth  := MMsToCoord(width);
               Arc.Radius     := MMsToCoord(abs(ival)+abs(jval));
               if (dx>0) and (dy>0) then begin
                   if (ival=0) then begin
                      Arc.StartAngle := 270;
                      Arc.EndAngle   := 360;
                   end else begin
                      Arc.StartAngle := 90;
                      Arc.EndAngle   := 180;
                   end;
               end else if (dx<0) and (dy<0) then begin
                   if (ival=0) then begin
                      Arc.StartAngle := 90;
                      Arc.EndAngle   := 180;
                   end else begin
                      Arc.StartAngle := 270;
                      Arc.EndAngle   := 360;
                   end;
               end else if (dx<0) and (dy>0) then begin
                   if (ival=0) then begin
                      Arc.StartAngle := 180;
                      Arc.EndAngle   := 270;
                   end else begin
                      Arc.StartAngle := 0;
                      Arc.EndAngle   := 90;
                   end;
               end else if (dx>0) and (dy<0) then begin
                   if (ival=0) then begin
                      Arc.StartAngle := 0;
                      Arc.EndAngle   := 90;
                   end else begin
                      Arc.StartAngle := 180;
                      Arc.EndAngle   := 270;
                   end;
               end;
               Arc.Selected:=true;
               Board.AddPCBObject(Arc);
               Arc.Selected:=true;
           end;
           LastX := xpos;
           LastY := ypos;
        end;
    end;

    // Create outline from selected tracks
    ResetParameters;
    AddStringParameter('Mode', 'BOARDOUTLINE_FROM_SEL_PRIMS');
    ok :=RunProcess('PCB:PlaceBoardOutline');

    // Deselect border
    ResetParameters;
    AddStringParameter('Scope', 'All');
    RunProcess('PCB:DeSelect');

    // Add connector
    CreateConnector(MaxX/2-15.5*2.54, MaxY-5.3-2.54, 32, 2, 2.54, 2.54, 'X1', 'Test interface');

    // Refresh PCB screen
    Client.CommandLauncher.LaunchCommand('PCB:Zoom', 'Action=Redraw' , 255, Client.CurrentView);
end;

function NewArc(x,y:double; radius:double; width:double; startangle, endangle: double): IPCB_Arc;
begin
    result := PCBServer.PCBObjectFactory(eArcObject, eNoDimension, eCreate_Default);
    result.XCenter    := MMsToCoord(x);
    result.YCenter    := MMsToCoord(y);
    result.Layer      := eMechanical1;
    result.LineWidth  := MMsToCoord(width);
    result.Radius     := MMsToCoord(radius);
    result.StartAngle := startangle;
    result.EndAngle   := endangle;
end;

procedure GenerateOutline(width, height: double);
var Track : IPCB_Track;  Arc: IPCB_Arc; ok:boolean;
begin
    // Bottom line
    Track := NewTrack(2.0, 0.0, width-2.0, 0.0, 0.15, eMechanical1);
    Board.AddPCBObject(Track);
    Track.selected := true;
    // Left edge
    Track := NewTrack(0.0, 2.0, 0.0, height-27.0, 0.15, eMechanical1);
    Board.AddPCBObject(Track);
    Track.selected := true;
    // Right edge
    Track := NewTrack(width, 2.0, width, height-27.0, 0.15, eMechanical1);
    Board.AddPCBObject(Track);
    Track.selected := true;
    // Left top vertical
    Track := NewTrack(35.0, height-23.0, 35.0, height-2.0, 0.15, eMechanical1);
    Board.AddPCBObject(Track);
    Track.selected := true;
    // Right top vertical
    Track := NewTrack(width-35.0, height-2.0, width-35.0, height-23.0, 0.15, eMechanical1);
    Board.AddPCBObject(Track);
    Track.selected := true;
    // Top center horizontal
    Track := NewTrack(37.0, height, width-37.0, height, 0.15, eMechanical1);
    Board.AddPCBObject(Track);
    Track.selected := true;
    // Left top horizontal
    Track := NewTrack(2.0, height-25.0, 33.0, height-25.0, 0.15, eMechanical1);
    Board.AddPCBObject(Track);
    Track.selected := true;
    // Right top horizontal
    Track := NewTrack(width-33.0, height-25.0, width-2.0, height-25.0, 0.15, eMechanical1);
    Board.AddPCBObject(Track);
    Track.selected := true;
    // Bottom arcs
    Arc := NewArc(2.0,       2.0, 2.0, 0.15, 180, 270);
    Board.AddPCBObject(Arc);
    Arc.selected := true;
    Arc := NewArc(width-2.0, 2.0, 2.0, 0.15, 270, 360);
    Board.AddPCBObject(Arc);
    Arc.selected := true;
    // Top arcs
    Arc := NewArc(2.0,       height-27.0, 2.0, 0.15,  90, 180);
    Board.AddPCBObject(Arc);
    Arc.selected := true;
    Arc := NewArc(width-2.0, height-27.0, 2.0, 0.15,   0,  90);
    Board.AddPCBObject(Arc);
    Arc.selected := true;
    Arc := NewArc(37.0,       height-2.0,  2.0, 0.15,  90, 180);
    Board.AddPCBObject(Arc);
    Arc.selected := true;
    Arc := NewArc(width-37.0, height-2.0,  2.0, 0.15,   0,  90);
    Board.AddPCBObject(Arc);
    Arc.selected := true;
    // Top inner corners
    Arc := NewArc(33.0,       height-23.0, 2.0, 0.15, 270, 360);
    Board.AddPCBObject(Arc);
    Arc.selected := true;
    Arc := NewArc(width-33.0, height-23.0, 2.0, 0.15, 180, 270);
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

    // Add connector
    CreateConnector(width/2-15.5*2.54, height-5.3-2.54, 32, 2, 2.54, 2.54, 'X1', 'Test interface');

    // Refresh PCB screen
    Client.CommandLauncher.LaunchCommand('PCB:Zoom', 'Action=Redraw' , 255, Client.CurrentView);
end;

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
    If SchNetlabel = Nil Then Exit;
    SchNetlabel.Location    := Point(MilsToCoord(xpos), MilsToCoord(ypos));
    SchNetlabel.Orientation := eRotate0;
    SchNetlabel.Text        := name;
    Schema.RegisterSchObjectInContainer(SchNetlabel);
end;

procedure PlaceSchTestPin(PinName, NetName: string; dia: double; xpos, ypos: double; var tpno:integer);
var SchNetlabel : ISch_Netlabel;  ok : boolen; s:string;  SchWire:ISch_Wire;
begin
    s:= 'Orientation=0|Location.X='+IntToStr(MilsToCoord(xpos))+'|Location.Y='
        +IntToStr(MilsToCoord(ypos))+'|designator='+PinName;
    tpno:=tpno+1;
    ok := IntegratedLibraryManager.PlaceLibraryComponent(
        TestPinName,
        LibraryFile,
        s);

    SchNetlabel := SchServer.SchObjectFactory(eNetlabel,eCreate_GlobalCopy);
    If SchNetlabel = Nil Then Exit;
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

    PlaceConnectorNet(12200, 10200-tpno*100, name);

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
var NetName, PinName, line: string; xpos, ypos: double; i, j:integer; tpno:integer;
begin
    tpno:=1;
    // Initialize the robots in Schematic editor.
    //SchServer.ProcessControl.PreProcess(Schema, '');
    PlaceConnector(13000, 10000);
    xpos:=800; ypos:=800;
    name:='-';
    Reset(InputFile);
    while not EOF(InputFile) do begin
        Readln(InputFile, line);
        if copy(line,1,6)='%TO.N,' then begin
            // Save net name
            i := pos('*',line);
            NetName := copy(line, 7, i-7);
        end else if copy(line,1,6)='%TO.C,' then begin
            // Save component name (f.ex. TP12)
            i := pos('*',line);
            NetName := copy(line, 7, i-7);
        end else if copy(line,1,4)='%ADD' then begin
            // Check for pin pads. Assume they are 1.3 or 1.5mm
            j:=pos('*',line);
            aperture:=strtoint(copy(line,5,3));
            diameters[aperture]:=strtofloat(copy(line,10,j-10));
        end else if line[1]='D' then begin
            aperture:=strtoint(copy(line,2,3));
        end else if (line[1}='X') and (name<>'-') and (diameters[aperture]>0.4) and (diameters[aperture]<2.6) then begin
            PlaceSchTestPin(PinName, NetName, 1.0, xpos, ypos, tpno);
            ypos:=ypos+300;
            if ypos>10000 then begin
                xpos:=xpos+1200;
                ypos:=800;
            end;
            name:='';
        end;
    end;
    SchServer.GetCurrentSchDocument.GraphicallyInvalidate;

end;


Procedure ParseMttFile(InputFile: TextFile);
var
    sizex, sizey: doble; i,j, n:  Integer; NetName, Designator, line, xpos, ypos, HoleDia, PinType : string; Dialog: TOpenDialog;
    comment:string;
begin
    n:=0;
    Reset(InputFile);
    while not EOF(InputFile) do begin
        Readln(InputFile, line);
        if copy(line,1,5)='SizeX' then begin
            SizeX := trunc(strtofloat(copy(line,7,999)));
        end else if copy(line,1,5)='SizeY' then begin
            SizeY := trunc(strtofloat(copy(line,7,999)));
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
            end;
            PlaceTestPinComp(strtoint(xpos)/1e6+SizeX/2, strtoint(ypos)/1e6+SizeY/2,
                Designator, PinType, NetName, strtoint(HoleDia)/1e6);
            n:=n+1;
        end;
    end;
    GenerateOutline(SizeX, SizeY);
end;

// Main procedure to run.
procedure Run;
var Dialog: TOpenDialog; InputFile: TextFile;  s:string;
begin
    s:='OK';
    Dialog:=TOpenDialog.Create(nil);
    Dialog.Filename:=DefaultFileName;
    if (DefaultFileName<>'') or Dialog.Execute then begin

        Client.StartServer('PCB');
        // Create a new pcb document
        WorkSpace := GetWorkSpace;
        If WorkSpace = Nil Then Exit;
        if CreateNewPcb then begin
           Workspace.DM_CreateNewDocument('PCB');
        end;

        // Check if PCB document exists
        If PCBServer = Nil Then Exit;
        Board := PCBServer.GetCurrentPCBBoard;
        If Board = Nil then exit;
        //PCBServer.PreProcess;

        AssignFile(InputFile, Dialog.Filename);
        if AnsiRightStr(Dialog.Filename,3)='gbr' then begin
            CalculateOffset(InputFile);
            CreateTestjigPcb(InputFile);
        end;

        {Client.StartServer('SCH');
        If SchServer = Nil Then Exit;
        if CreateNewSch then begin
           CreateNewDocumentFromDocumentKind('SCH');
        end;
        Schema := SchServer.GetCurrentSchDocument;
        //SchServer.ProcessControl.PreProcess(Schema, '');
        }
        if AnsiRightStr(Dialog.Filename,3)='gbr' then begin
            CreateTestjigSch(InputFile);
        end else if AnsiRightStr(Dialog.Filename,3)='mtt' then begin
            ParseMttFile(InputFile);
        end;
    end;
end;

