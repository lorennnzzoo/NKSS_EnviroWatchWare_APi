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
        private static readonly ILog logger = LogManager.GetLogger(typeof(NKSS_EnviroMonitor));
        private const string GROUPNAME = "EnviroMonitor";
        private bool isRunning = false; 
        private readonly IEnviroMonitorService enviroMonitorService;
        private readonly IConfigSettingService configSettingService;
        private readonly List<ConfigSetting> configSettings = new List<ConfigSetting>();
        private Timer dataLoggingTimer;
        public NKSS_EnviroMonitor(IEnviroMonitorService _enviroMonitorService, IConfigSettingService _configSettingService)
        {
            
            try
            {
                XmlConfigurator.Configure(new System.IO.FileInfo("log4net.config"));
                configSettingService = _configSettingService;
                enviroMonitorService = _enviroMonitorService;
                InitializeComponent();

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
            try
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
                logger.Info($"Initialized timer");
                DataLoggingTimer_Elapsed(null, null);
            }
            catch(Exception ex)
            {
                logger.Error("Error at OnStart", ex);
            }
            
        }

        private void DataLoggingTimer_Elapsed(object sender, ElapsedEventArgs e)
        {
            

            try
            {
                logger.Info("Timer elapsed");
                if (isRunning)
                {
                    logger.Info("Last thread still running so skipping");
                    return;
                }

                isRunning = true;

                logger.Info($"EnviroMonitor Started");
                enviroMonitorService.Run(configSettings);
                logger.Info($"EnviroMonitor Ended");
            }
            catch(Exception ex)
            {
                logger.Error($"Error at DataLoggingTimer_Elapsed", ex);
            }
            finally
            {
                isRunning = false;
            }
        }

        protected override void OnStop()
        {
            if (dataLoggingTimer != null)
            {
                logger.Info("Stopping and disposing the timer");
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
