﻿using NKSS_EnviroWatchWare_APi.Logging;
using System.Web;
using System.Web.Mvc;

namespace NKSS_EnviroWatchWare_APi
{
    public class FilterConfig
    {
        public static void RegisterGlobalFilters(GlobalFilterCollection filters)
        {
            filters.Add(new HandleErrorAttribute());            
        }
    }
}
