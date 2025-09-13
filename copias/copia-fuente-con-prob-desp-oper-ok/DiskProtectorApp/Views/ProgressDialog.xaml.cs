using MahApps.Metro.Controls;
using System.Windows;

namespace DiskProtectorApp.Views
{
    public partial class ProgressDialog : MetroWindow
    {
        public ProgressDialog()
        {
            InitializeComponent();
        }

        public void UpdateProgress(string operation, string progress)
        {
            OperationText.Text = operation;
            ProgressText.Text = progress;
        }

        public void SetProgressIndeterminate(bool isIndeterminate)
        {
            ProgressBar.IsIndeterminate = isIndeterminate;
        }
    }
}
