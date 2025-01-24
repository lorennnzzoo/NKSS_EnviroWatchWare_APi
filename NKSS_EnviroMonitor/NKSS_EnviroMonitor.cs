using Models;
using Services.Interfaces;
using Services.Interfaces.EnviroMonitor;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Diagnostics;
using System.Linq;
using System.ServiceProcess;
using System.Text;
using System.Threading.Tasks;
using System.Timers;

namespace NKSS_EnviroMonitor
{
    public partial class NKSS_EnviroMonitor : ServiceBase
    {
        private const string GROUPNAME = "EnviroMonitor";
        private bool isRunning = false; 
        private readonly IEnviroMonitorService enviroMonitorService;
        private readonly IConfigSettingService configSettingService;
        private readonly List<ConfigSetting> configSettings = new List<ConfigSetting>();
        private Timer dataLoggingTimer;
        public NKSS_EnviroMonitor(IEnviroMonitorService _enviroMonitorService, IConfigSettingService _configSettingService)
        {
            configSettingService = _configSettingService;
            enviroMonitorService = _enviroMonitorService;
            InitializeComponent();
            try
            {
                configSettings = configSettingService.GetConfigSettingsByGroupName(GROUPNAME).ToList();
                if (!configSettings.Any())
                {
                    throw new Services.Exceptions.NoRecordsFoundForGroupNameException(GROUPNAME);
                }
            }
            catch(Exception ex)
            {
                Environment.Exit(1);
            }
        }

        protected override void OnStart(string[] args)
        {
            int interval = GetIntervalFromConfig();
            dataLoggingTimer = new Timer(interval)
            {
                AutoReset = true, // Repeat the timer
                Enabled = true    // Start the timer
            };
            dataLoggingTimer.Elapsed += DataLoggingTimer_Elapsed;
            DataLoggingTimer_Elapsed(null, null);
        }

        private void DataLoggingTimer_Elapsed(object sender, ElapsedEventArgs e)
        {
            if (isRunning)
            {
                return;  // Skip if the task is still running
            }
            isRunning = true;

            try
            {
                enviroMonitorService.Run(configSettings);
            }
            finally
            {
                isRunning = false;  // Reset the flag after the task is complete
            }
        }

        protected override void OnStop()
        {
            if (dataLoggingTimer != null)
            {
                dataLoggingTimer.Stop();
                dataLoggingTimer.Dispose();
            }
        }

        private int GetIntervalFromConfig()
        {
            var intervalSetting = configSettings.FirstOrDefault(s => s.ContentName == "ServiceInterval");
            if (intervalSetting != null && int.TryParse(intervalSetting.ContentValue, out int interval))
            {
                return interval;
            }

            return 60000; // Default to 1 minute
        }
    }
}
