//----------------------------------------------------------
// Import Elrpint testjig pcb from gerber or mtt files
// (c)Jan K�re Vatne 2022, jkvatne@online.no
// MIT Licence, free to use and modify.
//----------------------------------------------------------


// Constants for configuration of generator
// Change them as required
const
    CreateNewPcb = true;         // Set true to create new file. When false it will update current pcb
    ReliefWidth = 0.254;         // Relief width and air gap.
    SolderMaskExpansion = 0.01;
    DefaultFileName = 'C:\doc\RollsRoyce\RRLC2-hardware\Test jig\248218 test circuitry outline.gbr';
    // For pins with 2mm spacing, and 1.2mm holes we can have 0.2mm cledarance and 0.3mm anular ring.
    HoleDiameter = 1.2;          // The pcb hole for the needle holders. Typicaly they have 1mm dia round pins for all needle sizes.
    AnularRing   = 0.3;          // Needle hole anular ring. Not less than 0.2mm

// Global variables
var
    Board     : IPCB_Board;
    WorkSpace : IWorkSpace;
    SizeX, SizeY : double;
    OffsetX, OffsetY : double;
    MaxX, MaxY :  double;
    LastX, Lasty: double;

// Place a pad on the pcb. All dimensions in millimeters.
Function PlaceAPCBPad(AX,AY : double; ATopSize, AHoleSize : double; ALayer : TLayer; AName : string; round: boolean) : IPCB_Pad;
Var
    P        : IPCB_Pad;
    PadCache : TPadCache;
Begin
    Result := Nil;
    P := PcbServer.PCBObjectFactory(ePadObject,eNoDimension,eCreate_Default);
    If P = Nil Then Exit;

    P.X        := MMsToCoord(AX);
    P.Y        := MMsToCoord(AY);
    P.TopXSize := MMsToCoord(ATopSize);
    P.TopYSize := MMsToCoord(ATopSize);
    if round then begin
        P.TopShape := eRounded;
    end else begin
        P.TopShape := eRectangular;
    end;
    P.HoleSize := MMsToCoord(AHoleSize);
    P.Layer    := ALayer;
    P.Name     := AName;

    // Setup a pad cache
    Padcache := P.GetState_Cache;
    Padcache.ReliefAirGap              := MMsToCoord(ReliefWidth);
    Padcache.PowerPlaneReliefExpansion := MMsToCoord(ReliefWidth);
    Padcache.PowerPlaneClearance       := MMsToCoord(ReliefWidth);
    Padcache.ReliefConductorWidth      := MMsToCoord(ReliefWidth);
    Padcache.SolderMaskExpansion       := MMsToCoord(SolderMaskExpansion);
    Padcache.SolderMaskExpansionValid  := eCacheManual;
    Padcache.PasteMaskExpansion        := 0;
    Padcache.PasteMaskExpansionValid   := eCacheManual;

    // Assign the new pad cache to the pad
    P.SetState_Cache(Padcache);
    Result := P;
End;


// Place a track on the pcb. All dimensions in millimeters.
Function PlaceAPCBTrack(x1, y1, x2, y2 : double; width : double; ALayer : TLayer) : IPCB_Track;
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


// PLace a test pin on pcb. All dimensions im millimeters.
Procedure PlaceTestPin(x,y : double; name:string, dia: double, rotation: double);
Var
    Comp : IPCB_Component;
    NewPad : IPCB_Pad;
    NewNet : IPCB_Net;
    Iterator : IPCB_BoardIterator;
Begin
    Comp := PCBServer.PCBObjectFactory(eComponentObject, eNoDimension, eCreate_Default);
    If Comp = Nil Then Exit;

    // Create a pad
    NewPad := PlaceAPCBPad(0,0, HoleDiameter+2*AnularRing, HoleDiameter, eMultiLayer, '1', true);
    Comp.AddPCBObject(NewPad);
    PCBServer.SendMessageToRobots(Comp.I_ObjectAddress,c_Broadcast,PCBM_BoardRegisteration, NewPad.I_ObjectAddress);

    if name<>'' then begin
        Iterator := Board.BoardIterator_Create;
        Iterator.AddFilter_ObjectSet(MkSet(eNetObject));
        NewNet := Iterator.FirstPCBObject;
        while Newnet<>nil do begin
           if NewNet.Name=name then begin
               break;
           end;
           NewNet := Iterator.NextPCBObject;
        end;
        if NewNet=nil then begin
            NewNet := PCBServer.PCBObjectFactory(eNetObject, eNoDimension, eCreate_Default);
            NewNet.Name :=name;
        end;
        Board.AddPCBObject(NewNet);
        PCBServer.SendMessageToRobots(Board.I_ObjectAddress,c_Broadcast,PCBM_BoardRegisteration,NewNet.I_ObjectAddress);
    end;

    NewPad.net:=NewNet;

    // Set the reference point of the Component
    Comp.X         := MmsToCoord(x);
    Comp.Y         := MmsToCoord(y);
    Comp.Layer     := eTopLayer;

    // Make the designator text visible;
    Comp.NameOn         := True;
    Comp.Name.Text      := name;
    Comp.Name.Size      := MmsToCoord(1.0);
    Comp.Name.Rotation  := rotation;
    Comp.Name.XLocation := MmsToCoord(x - 0.4);
    Comp.Name.YLocation := MmsToCoord(y - dia);

    // Make the comment NOT text visible;
    Comp.CommentOn         := False;
    Comp.Comment.Text      := '';
    Comp.Comment.XLocation := MmsToCoord(x+1.0);
    Comp.Comment.YLocation := MmsToCoord(y+2);

    Board.AddPCBObject(Comp);
    PCBServer.SendMessageToRobots(Board.I_ObjectAddress,c_Broadcast,PCBM_BoardRegisteration,Comp.I_ObjectAddress);
End;


Procedure ParseMttFile;
Var
    InputFile: TextFile; i,j, n:  Integer; name, line, xpos, ypos, dia : string; Dialog: TOpenDialog;
begin
    n:=0;
    Dialog:=TOpenDialog.Create(nil);
    Dialog.Filename:='C:\doc\RollsRoyce\RRLC2-hardware\Test jig\RRLC2 test fixture.mtt';
    //if Dialog.Execute then begin
        AssignFile(InputFile, Dialog.Filename);
        Reset(InputFile);
        while not EOF(InputFile) do begin
             Readln(InputFile, line);
             if copy(line,1,5)='SizeX' then begin
                SizeX := trunc(1e6*strtofloat(copy(line,7,999)));
             end else if copy(line,1,5)='SizeY' then begin
                SizeY := trunc(1e6*strtofloat(copy(line,7,999)));
             end else if copy(line,1,6)='PinItm' then begin
                i := pos('=',line);
                line := copy(line, i+1, 9999);
                i := pos('|',line);
                name := copy(line, 1, i-1);
                line := copy(line, i+1, 9999);
                i := pos('|',line);
                line := copy(line, i+1, 9999);
                i := pos('|',line);
                xpos := copy(line, 1, i-1);
                line := copy(line, i+1, 9999);
                i := pos('|',line);
                ypos := copy(line, 1, i-1);
                line := copy(line, i+1, 9999);
                i := pos('|',line);
                dia := copy(line, 1, i-1);
                PlaceTestPin(name, strtoint(xpos)+SizeX/2, strtoint(ypos)+SizeY/2, strtoint(dia), 270.0);
                n:=n+1;
             end;
        end;
    //end;
end;


procedure CalculateOffset(InputFile);
var line string; i,j: integer; xpos,ypos: double;
begin
    MaxX := -99999.9;
    MaxY := -99999.9;
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
    NewPad : IPCB_Pad;
    i,j:integer;
begin
    Comp := PCBServer.PCBObjectFactory(eComponentObject, eNoDimension, eCreate_Default);
    If Comp = Nil Then Exit;

    // Create a pad
    for j:=1 to ny do begin
        for i:=1 to nx do begin
            NewPad := PlaceAPCBPad((i-1)*dx, (j-1)*2.54, 1.8, 1.0, eMultiLayer, inttostr((i-1)*ny +j), (i<>1) or (j<>1));
            Comp.AddPCBObject(NewPad);
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
    PCBServer.SendMessageToRobots(Board.I_ObjectAddress,c_Broadcast,PCBM_BoardRegisteration,Comp.I_ObjectAddress);

end;


procedure ParseGerberFile(InputFile: TextFile);
var i,j,k: integer; cmd, name, line: string;
    NewTrack : IPCB_Track;  Arc: IPCB_Arc;
    ival,jval,dx,dy,xpos,ypos,dia,width: double;
begin
    dia:=1.3;
    width:=0.254;
    name:='-';
    while not EOF(InputFile) do begin
        Readln(InputFile, line);
        if copy(line,1,6)='%TO.N,' then begin
            // Save name
            i := pos('*',line);
            name := copy(line, 7, i-7);
        end else if (copy(line[1],1,1)='X') and (name<>'-') then begin
            i := pos('Y',line);
            xpos:=strtoint(copy(line,2,i-2))/1e6+OffsetX;
            j := pos('D', line);
            ypos:=strtoint(copy(line, i+1, j-i-1))/1e6+OffsetY;
            PlaceTestPin(xpos, ypos, name, dia, 270.0);
            name:='';
        end else if (copy(line[1],1,1)='X') then begin
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
               NewTrack := PlaceAPCBTrack(xpos, ypos, lastx, lasty, width, eMechanical1);
               Board.AddPCBObject(NewTrack);
               NewTrack.Selected:=true;
               PCBServer.SendMessageToRobots(NewTrack.I_ObjectAddress,c_Broadcast,PCBM_BoardRegisteration,NewTrack.I_ObjectAddress);
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
end;

procedure CreateTestjig;
var
  InputFile: TextFile;
  Dialog: TOpenDialog;
  n:integer;
begin
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

    PCBServer.PreProcess;

    Dialog:=TOpenDialog.Create(nil);
    Dialog.Filename:=DefaultFileName;
    if (DefaultFileName<>'') or Dialog.Execute then begin
        AssignFile(InputFile, Dialog.Filename);
        Reset(InputFile);
        CalculateOffset(InputFile);
        Reset(InputFile);
        ParseGerberFile(InputFile);
    end;

    PCBServer.PostProcess;

    Client.CommandLauncher.LaunchCommand('PCB:PlaceBoardOutline', 'Mode=BOARDOUTLINE_FROM_SEL_PRIMS', 255, Client.CurrentView);
    CreateConnector(MaxX/2-15.5*2.54, MaxY-5.3-2.54, 32, 2, 2.54, 2.54, 'X1', 'Test interface');

    // Refresh PCB workspace.
    ResetParameters;
    AddStringParameter('Mode', 'BOARDOUTLINE_FROM_SEL_PRIMS');
    RunProcess('PCB:PlaceBoardOutline');

    // Deselect border
    ResetParameters;
    AddStringParameter('Scope', 'All');
    RunProcess('PCB:DeSelect');
    //Client.CommandLauncher.LaunchCommand('PCB:DeSelect', 'Scope=All' , 255, Client.CurrentView);

    // Refresh PCB screen
    Client.CommandLauncher.LaunchCommand('PCB:Zoom', 'Action=Redraw' , 255, Client.CurrentView);
end;
