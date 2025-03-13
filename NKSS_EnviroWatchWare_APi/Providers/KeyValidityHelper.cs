using Repositories;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace NKSS_EnviroWatchWare_APi.Providers
{
    public class KeyValidityHelper
    {
        static ConfigSettingRepository configSettingsRepository = new ConfigSettingRepository();
        private static readonly string groupName = "ApiIngestor";
        private static readonly string contentName = "IngestorKey";
        public static bool CheckKeyValidity(string key)
        {
            var settings=configSettingsRepository.GetByGroupName(groupName);
            if (settings.Any())
            {                
                var apiKeys = settings.Where(s => s.ContentName == contentName);
                if (apiKeys.Any())
                {
                    return apiKeys.Any(a => a.ContentValue == key);
                }
                else
                {
                    return false;
                }
            }
            else
            {
                return false;
            }
        }
    }
}