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
        private static readonly string groupName = "ApiContract";
        public static bool CheckKeyValidity(string key)
        {
            var settings=configSettingsRepository.GetByGroupName(groupName);
            if (settings.Any())
            {
                return settings.Any(a => a.ContentName == key.Trim());
            }
            else
            {
                return false;
            }
        }
    }
}