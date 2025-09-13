using MahApps.Metro.Controls;
using System.Windows;

namespace DiskProtectorApp.Views
{
    public partial class MessageBoxWindow : MetroWindow
    {
        public MessageBoxResult Result { get; private set; } = MessageBoxResult.None;

        public MessageBoxWindow()
        {
            InitializeComponent();
        }

        public static MessageBoxResult ShowDialog(string message, string title, MessageBoxButton buttons, Window? owner)
        {
            var messageBox = new MessageBoxWindow
            {
                Title = title,
                Owner = owner
            };

            messageBox.MessageText.Text = message;

            // Configurar botones según el tipo solicitado
            switch (buttons)
            {
                case MessageBoxButton.OK:
                    messageBox.OkButton.Visibility = Visibility.Visible;
                    messageBox.OkButton.Focus();
                    break;
                case MessageBoxButton.YesNo:
                    messageBox.YesButton.Visibility = Visibility.Visible;
                    messageBox.NoButton.Visibility = Visibility.Visible;
                    messageBox.YesButton.Focus();
                    break;
                case MessageBoxButton.YesNoCancel:
                    messageBox.YesButton.Visibility = Visibility.Visible;
                    messageBox.NoButton.Visibility = Visibility.Visible;
                    messageBox.CancelButton.Visibility = Visibility.Visible;
                    messageBox.YesButton.Focus();
                    break;
                default:
                    messageBox.OkButton.Visibility = Visibility.Visible;
                    messageBox.OkButton.Focus();
                    break;
            }

            messageBox.ShowDialog();
            return messageBox.Result;
        }

        private void OkButton_Click(object sender, RoutedEventArgs e)
        {
            Result = MessageBoxResult.OK;
            this.Close();
        }

        private void YesButton_Click(object sender, RoutedEventArgs e)
        {
            Result = MessageBoxResult.Yes;
            this.Close();
        }

        private void NoButton_Click(object sender, RoutedEventArgs e)
        {
            Result = MessageBoxResult.No;
            this.Close();
        }

        private void CancelButton_Click(object sender, RoutedEventArgs e)
        {
            Result = MessageBoxResult.Cancel;
            this.Close();
        }
    }
}
