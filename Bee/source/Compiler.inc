// BEE 0.7.9 project compiler directives

// Common directive

{*$DEFINE DEBUG}

{$ifdef Verbose}
  {$define Debug}
{$endif}

{$ifdef Debug}
  {$R+,Q+,C+,S-,W-,O-}
  {$inline off}
{$else}
  {$R-,Q-,C-,I-,S-,W-,O+}
  {$inline auto}
{$endif}

{$pointermath on}

{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}
{$WEAKLINKRTTI ON}

// Application type directive (use with FPC\Lazarus)

{*$DEFINE GUI}
{*$DEFINE CONSOLE}

