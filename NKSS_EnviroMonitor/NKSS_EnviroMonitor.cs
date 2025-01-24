using log4net;
using log4net.Config;
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
        private static readonly ILog logger = LogManager.GetLogger(typeof(Program));
        private const string GROUPNAME = "EnviroMonitor";
        private bool isRunning = false; 
        private readonly IEnviroMonitorService enviroMonitorService;
        private readonly IConfigSettingService configSettingService;
        private readonly List<ConfigSetting> configSettings = new List<ConfigSetting>();
        private Timer dataLoggingTimer;
        public NKSS_EnviroMonitor(IEnviroMonitorService _enviroMonitorService, IConfigSettingService _configSettingService)
        {
            XmlConfigurator.Configure(new System.IO.FileInfo("log4net.config"));
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
                logger.Info($"Config settings for {GROUPNAME} count : {configSettings.Count}");
            }
            catch(Exception ex)
            {
                logger.Error("Error at NKSS_EnviroMonitor Constructor",ex);
                Environment.Exit(1);
            }
        }

        protected override void OnStart(string[] args)
        {
            logger.Info("Service started");
            int interval = GetIntervalFromConfig();
            logger.Info($"Service Interval : {interval}");
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
            logger.Info("Timer elapsed");
            if (isRunning)
            {
                logger.Info("Last thread still running so skipping");
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
            logger.Info("Service stopped");
        }

        private int GetIntervalFromConfig()
        {
            var intervalSetting = configSettings.FirstOrDefault(s => s.ContentName == "ServiceInterval");
            if (intervalSetting != null && int.TryParse(intervalSetting.ContentValue, out int interval))
            {
                return interval;
            }
            logger.Info($"Service Interval not found using default 60seconds");
            return 60000; // Default to 1 minute
        }
    }
}
