using MahApps.Metro.Controls;
using System;
using System.Threading;
using System.Windows;

namespace DiskProtectorApp.Views
{
    public partial class ProgressDialog : MetroWindow
    {
        private CancellationTokenSource? _cancellationTokenSource;
        
        public ProgressDialog()
        {
            InitializeComponent();
        }
        
        public CancellationToken CancellationToken 
        { 
            get 
            { 
                _cancellationTokenSource ??= new CancellationTokenSource();
                return _cancellationTokenSource.Token; 
            } 
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
        
        public void AddDetail(string detail)
        {
            // Agregar timestamp y detalle
            string timestamp = DateTime.Now.ToString("HH:mm:ss");
            string detailLine = $"[{timestamp}] {detail}";
            
            // Agregar al texto de detalles
            if (string.IsNullOrEmpty(DetailsText.Text))
            {
                DetailsText.Text = detailLine;
            }
            else
            {
                DetailsText.Text += Environment.NewLine + detailLine;
            }
            
            // Hacer scroll automático al final usando ScrollViewer
            var scrollViewer = DetailsText.Parent as System.Windows.Controls.ScrollViewer;
            if (scrollViewer != null)
            {
                scrollViewer.ScrollToVerticalOffset(scrollViewer.ExtentHeight);
            }
        }
        
        public void ClearDetails()
        {
            DetailsText.Text = string.Empty;
        }

        private void CancelButton_Click(object sender, RoutedEventArgs e)
        {
            _cancellationTokenSource?.Cancel();
            CancelButton.IsEnabled = false;
            CancelButton.Content = "Cancelando...";
        }
    }
}
