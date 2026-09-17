namespace Gallery.WinUI;

/// <summary>
/// WinUI bootstrap. The only XAML file in the project and required by the
/// platform - it contains no application UI, which is declared in Swift.
/// </summary>
public partial class App : MauiWinUIApplication
{
    public App()
    {
        InitializeComponent();
    }

    protected override MauiApp CreateMauiApp() => MauiProgram.CreateMauiApp();
}
