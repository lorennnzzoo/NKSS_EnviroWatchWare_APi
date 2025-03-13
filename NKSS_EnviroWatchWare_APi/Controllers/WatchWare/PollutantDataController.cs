using Models.PollutionData;
using NKSS_EnviroWatchWare_APi.Providers;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;

namespace NKSS_EnviroWatchWare_APi.Controllers.WatchWare
{
    [PollutantAuthorize]    
    [RoutePrefix("PollutantData")]
    public class PollutantDataController : ApiController
    {
        [HttpPost]
        [Route("Upload")]
        public IHttpActionResult Upload(PollutantDataUploadRequest Request)
        {            
            try
            {
                return Ok();
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }

        [HttpPost]
        [Route("UploadBulk")]
        public IHttpActionResult UploadBulk()
        {
            try
            {
                return Ok();
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }        
    }
}
