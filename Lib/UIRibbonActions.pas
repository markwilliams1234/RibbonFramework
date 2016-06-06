unit UIRibbonActions;

interface

uses
  System.Classes,
  ActnList,
  ActnMan,
  UIRibbonCommands;

type
  TUICommandActionLink = class abstract (TActionLink)
  {$REGION 'Internal Declarations'}
  strict private
    FClient: TUICommand;
  {$ENDREGION 'Internal Declarations'}
  protected
    procedure SetAction(Value: TBasicAction); override;
    procedure AssignClient(AClient: TObject); override;
    function IsEnabledLinked: Boolean; override;
    function IsOnExecuteLinked: Boolean; override;
    procedure SetCaption(const Value: String); override;
    procedure SetEnabled(Value: Boolean); override;
    procedure SetVisible(Value: Boolean); override;
    procedure SetHint(const Value: String); override;
    procedure SetShortCut(Value: System.Classes.TShortCut); override;
    procedure SetImageIndex(Value: Integer); override;
    procedure SetOnExecute(Value: TNotifyEvent); override;

    property Client: TUICommand read FClient;
  public
    constructor Create(const AClient: TUICommand); reintroduce;
    function Update: Boolean; override;
  end;

  TUICommandEmptyActionLink = class(TUICommandActionLink)
    { No additional declarations }
  end;

  TUICommandActionActionLink = class(TUICommandActionLink)
  {$REGION 'Internal Declarations'}
  strict private
    procedure CommandExecute(const Args: TUICommandActionEventArgs);
  {$ENDREGION 'Internal Declarations'}
  protected
    procedure SetAction(Value: TBasicAction); override;
  end;

  TUICommandCollectionActionLink = class(TUICommandActionLink)
  {$REGION 'Internal Declarations'}
  strict private
    procedure CommandSelect(const Args: TUICommandCollectionEventArgs);
  {$ENDREGION 'Internal Declarations'}
  protected
    procedure SetAction(Value: TBasicAction); override;
  end;

  TUICommandDecimalActionLink = class(TUICommandActionLink)
  {$REGION 'Internal Declarations'}
  strict private
    procedure CommandChange(const Command: TUICommandDecimal;
      const Verb: TUICommandVerb; const Value: Double;
      const Properties: TUICommandExecutionProperties);
  {$ENDREGION 'Internal Declarations'}
  protected
    procedure SetAction(Value: TBasicAction); override;
  end;

  TUICommandBooleanActionLink = class(TUICommandActionLink)
  {$REGION 'Internal Declarations'}
  strict private
    procedure CommandToggle(const Args: TUICommandBooleanEventArgs);
  {$ENDREGION 'Internal Declarations'}
  protected
    procedure SetAction(Value: TBasicAction); override;
    procedure SetChecked(Value: Boolean); override;
  end;

  TUICommandFontActionLink = class(TUICommandActionLink)
  {$REGION 'Internal Declarations'}
  strict private
    procedure CommandChanged(const Args: TUICommandFontEventArgs);
  {$ENDREGION 'Internal Declarations'}
  protected
    procedure SetAction(Value: TBasicAction); override;
  end;

  TUICommandColorAnchorActionLink = class(TUICommandActionLink)
  {$REGION 'Internal Declarations'}
  strict private
    procedure CommandExecute(const Args: TUICommandColorEventArgs);
  {$ENDREGION 'Internal Declarations'}
  protected
    procedure SetAction(Value: TBasicAction); override;
  end;

  TUICommandRecentItemsActionLink = class(TUICommandActionLink)
  {$REGION 'Internal Declarations'}
  strict private
    fSelected: TUIRecentItem;
    procedure CommandSelect(const Command: TUICommandRecentItems;
      const Verb: TUICommandVerb; const ItemIndex: Integer;
      const Properties: TUICommandExecutionProperties);
  {$ENDREGION 'Internal Declarations'}
  protected
    procedure SetAction(Value: TBasicAction); override;
  public
    //Added property "Selected" to allow access to selected item.
    //TODO: Create a custom action that provides the required properties.
    property Selected: TUIRecentItem read fSelected write fSelected;
  end;

  TRibbonAction<T:TUICommand> = class(TCustomAction)
  private
    fUICommand: T;
  public
    property UICommand: T read fUICommand write fUICommand;
  published
    property Caption;
    property Enabled;
    property HelpContext;
    property HelpKeyword;
    property HelpType;
    property Hint;
    property SecondaryShortCuts;
    property ShortCut default 0;
    property OnExecute;
    property OnHint;
    property OnUpdate;
  end;

  TRibbonCollectionAction = class(TRibbonAction<TUICommandCollection>)
  end;

  TRibbonColorAction = class(TRibbonAction<TUICommandColorAnchor>)
  end;

  TRibbonFontAction = class(TRibbonAction<TUICommandFont>)
  strict private
    fOnChanged: TUICommandFontChangedEvent;
  published
    { Fired when one or more of the font properties has changed.
      When the Verb is cvExecute or cvPreview, then the Font parameter of the
      event contains the new font settings. Otherwise, the Font parameter
      contains the current font settings. }
    property OnChanged: TUICommandFontChangedEvent read fOnChanged write fOnChanged;
  end;


implementation

uses
  Menus,
  Controls,
  {$if CompilerVersion >= 24}
  System.Actions,
  {$endif}
  System.SysUtils; 

{ TUICommandActionLink }

procedure TUICommandActionLink.AssignClient(AClient: TObject);
begin
  inherited;
  FClient := AClient as TUICommand;
end;

constructor TUICommandActionLink.Create(const AClient: TUICommand);
begin
  inherited Create(AClient);
end;

function TUICommandActionLink.IsEnabledLinked: Boolean;
begin
  Result := inherited IsEnabledLinked and (FClient.Enabled = (Action as TCustomAction).Enabled);
end;

function TUICommandActionLink.IsOnExecuteLinked: Boolean;
begin
  Result := False;
end;

procedure TUICommandActionLink.SetAction(Value: TBasicAction);
begin
  inherited;
  if Value is TCustomAction then with TCustomAction(Value) do
  begin
    // Trigger assigned OnUpdate method to determine whether the Ribbon command
    // shall be enabled or disabled (greyed out).
    Value.Update();
    Self.SetEnabled(Enabled and Visible);
    // Caption of the Ribbon Command
    Self.SetCaption(Caption);
    Self.SetHint(Hint);
    Self.SetChecked(Checked);
    Self.SetGroupIndex(GroupIndex);
    Self.SetShortCut(ShortCut);
    Self.SetImageIndex(ImageIndex);
  end;// if/with
end;

procedure TUICommandActionLink.SetCaption(const Value: String);
const
  cAmpersand = '&';
begin
  if IsCaptionLinked and (Value <> '') then begin
    FClient.Caption := Trim(Value.Replace('...', ''));// Remove trailing dots, they are uncommon in ribbon bars
    // Tooltip Title (bold string above the actual Tooltip)
    // Using the value of caption here because common Microsoft products do this as well.
    FClient.TooltipTitle := Value;
    // If action caption contains an ampersand (&), use the char following that
    // ampersand as Keytip for the ribbon element so that ALT+Char can be used the
    // same way as on regular VCL controls.
    if Value.Contains(cAmpersand) then
    begin
      FClient.Keytip := UpperCase(Value[Value.IndexOf(cAmpersand) + 2]);
    end;
  end;
  // For some reasons, the Windows Ribbon Framework makes the ToolTipTitle
  // invisible, if it equals the Commands Caption property. To aovid this, we
  // assign an additional space to the end of the string here.
  FClient.TooltipTitle := FClient.TooltipTitle + ' ';
end;

procedure TUICommandActionLink.SetEnabled(Value: Boolean);
begin
  if IsEnabledLinked then
    FClient.Enabled := Value;
end;

procedure TUICommandActionLink.SetVisible(Value: Boolean);
begin
  inherited;
  // The Windows ribbon framework does not off to make a button invisible at runtime, so we at least disable the button
  if not Value then
    FClient.Enabled := False;
end;

procedure TUICommandActionLink.SetShortCut(Value: System.Classes.TShortCut);
begin
  // If corresponding Action has a shortcut, we append it in text form to the TooltipTitle.
  if Value <> 0 then
  begin
    FClient.ShortCut := Value;
    FClient.TooltipTitle := Format('%s (%s)', [FClient.Caption, ShortCutToText(Value)]);
  end;
end;

function TUICommandActionLink.Update: Boolean;
begin
  if Assigned(Self.Action) then
    Result := inherited Update()
  else
    Result := False;
end;

procedure TUICommandActionLink.SetHint(const Value: String);
begin
  if IsHintLinked and not Value.IsEmpty then
  begin
    // Use the long hint of the action as TooltipDescription. If no separate
    // strings for Long and Short hint are provided, the regular string is used.
    FClient.TooltipDescription := GetLongHint(Value);

    //    I := Pos('|', Value);
//    if (I = 0) then
//      FClient.TooltipTitle := Value
//    else
//    begin
//      FClient.TooltipTitle := Copy(Value, 1, I - 1);
//      FClient.TooltipDescription := Copy(Value, I + 1, MaxInt);
//    end;

    // Some extra handling for the regular ribbon buttons (ctAction).
    if (FClient.CommandType = TUICommandType.ctAction) then
    begin
      // Regular ribbon buttons may also have a "Description" (this is not the
      // tooltip that any ribbon element has), which is displayed right beneath
      // the caption of large buttons in sub menus such as the application menu.
      // Use the short hint of the action as TooltipDescription. If no separate
      // strings for Long and Short hint are provided, the regular string is used.
      (FClient as TUICommandAction).LabelDescription := GetShortHint(Value);
    end;

    if assigned(FClient.OnUpdateHint) then
      FClient.OnUpdateHint(FClient, Value);
  end;
end;

procedure TUICommandActionLink.SetImageIndex(Value: Integer);
var
  lActionManager: TActionManager;
begin
  inherited;
  if (Value >= 0) and (Self.Action is TContainedAction) and (TContainedAction(Self.Action).ActionList is TActionManager) then begin
    lActionManager := TActionManager(TContainedAction(Self.Action).ActionList);
    if Assigned(lActionManager.Images) then
      FClient.SmallImage := TUIImage.Create(lActionManager.Images, Value);
    if Assigned(lActionManager.LargeImages) then
      FClient.LargeImage := TUIImage.Create(lActionManager.LargeImages, Value);
  end;
end;

procedure TUICommandActionLink.SetOnExecute(Value: TNotifyEvent);
begin
  { No implementation }
end;

{ TUICommandActionActionLink }

procedure TUICommandActionActionLink.CommandExecute(
  const Args: TUICommandActionEventArgs);
begin
  if Assigned(Action) then
    Action.Execute;
end;

procedure TUICommandActionActionLink.SetAction(Value: TBasicAction);
begin
  inherited;
  if Assigned(Value) then
    (Client as TUICommandAction).OnExecute := CommandExecute;
end;

{ TUICommandCollectionActionLink }

procedure TUICommandCollectionActionLink.CommandSelect(
  const Args: TUICommandCollectionEventArgs);
begin
  if Assigned(Action) then
    Action.Execute;
end;

procedure TUICommandCollectionActionLink.SetAction(Value: TBasicAction);
begin
  inherited;
  (Client as TUICommandCollection).OnSelect := CommandSelect;
  if (Action is TRibbonCollectionAction) then
    TRibbonCollectionAction(Action).UICommand := (Client as TUICommandCollection);
end;

{ TUICommandDecimalActionLink }

procedure TUICommandDecimalActionLink.CommandChange(
  const Command: TUICommandDecimal; const Verb: TUICommandVerb;
  const Value: Double; const Properties: TUICommandExecutionProperties);
begin
  if Assigned(Action) then
    Action.Execute;
end;

procedure TUICommandDecimalActionLink.SetAction(Value: TBasicAction);
begin
  inherited;
  if Assigned(Value) then
    (Client as TUICommandDecimal).OnChange := CommandChange;
end;

{ TUICommandBooleanActionLink }

procedure TUICommandBooleanActionLink.CommandToggle(const Args: TUICommandBooleanEventArgs);
begin
  if Assigned(Action) then
    Action.Execute;
  // sync the Toogle state of the ribbon buton with the action. This is important as the ToggleButton toggles automatically.
  if IsCheckedLinked and Args.Command.Checked <> TContainedAction(Action).Checked then
  begin
    // TBasicAction does not have a Checked property
    SetChecked(TContainedAction(Action).Checked);
  end;//if
end;

procedure TUICommandBooleanActionLink.SetAction(Value: TBasicAction);
begin
  inherited;
  if Assigned(Value) then
    (Client as TUICommandBoolean).OnToggle := CommandToggle;
end;

procedure TUICommandBooleanActionLink.SetChecked(Value: Boolean);
begin
  inherited;
  // Toggle buttons have a "Checked" property, set it to the same state as
  // its corresponding TAction element has.
  (Client as TUICommandBoolean).Checked := Value;
end;

{ TUICommandFontActionLink }

procedure TUICommandFontActionLink.CommandChanged(
  const Args: TUICommandFontEventArgs);
begin
  if not Assigned(Action) then exit;
  if (Action is TRibbonFontAction) and Assigned(TRibbonFontAction(Action).OnChanged) then
    TRibbonFontAction(Action).OnChanged(Args)
  else
    Action.Execute;
end;

procedure TUICommandFontActionLink.SetAction(Value: TBasicAction);
begin
  inherited;
  if Assigned(Value) then
    (Client as TUICommandFont).OnChanged := CommandChanged;
  if (Action is TRibbonFontAction) then
    TRibbonFontAction(Action).UICommand := (Client as TUICommandFont);
end;

{ TUICommandColorAnchorActionLink }

procedure TUICommandColorAnchorActionLink.CommandExecute(
  const Args: TUICommandColorEventArgs);
begin
  if Assigned(Action) then
    Action.Execute;
end;

procedure TUICommandColorAnchorActionLink.SetAction(Value: TBasicAction);
begin
  inherited;
  if Assigned(Value) then
    (Client as TUICommandColorAnchor).OnExecute := CommandExecute;
  if (Action is TRibbonColorAction) then
    TRibbonColorAction(Action).UICommand := (Client as TUICommandColorAnchor);
end;

{ TUICommandRecentItemsActionLink }

procedure TUICommandRecentItemsActionLink.CommandSelect(
  const Command: TUICommandRecentItems; const Verb: TUICommandVerb;
  const ItemIndex: Integer; const Properties: TUICommandExecutionProperties);
var
  lItem: IUICollectionItem;
begin
  //[JAM:Lemke] Filling property "Selected" with required information

  lItem := Command.Items.Items[ItemIndex];

  Self.Selected := TUIRecentItem.Create;
  try
    Self.Selected.LabelText := (lItem as TUIRecentItem).LabelText;
    Self.Selected.Description := (lItem as TUIRecentItem).Description;
    Self.Selected.Pinned := (lItem as TUIRecentItem).Pinned;

    if Assigned(Action) then
      Action.Execute;
  finally
    FreeAndNil(fSelected);
  end;
end;

procedure TUICommandRecentItemsActionLink.SetAction(Value: TBasicAction);
begin
  inherited;
  if Assigned(Value) then
    (Client as TUICommandRecentItems).OnSelect := CommandSelect;
end;

end.
