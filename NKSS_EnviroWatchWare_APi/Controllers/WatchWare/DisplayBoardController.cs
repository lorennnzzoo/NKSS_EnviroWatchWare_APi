using Models.DisplayBoard;
using Services;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;

namespace NKSS_EnviroWatchWare_APi.Controllers.WatchWare
{
    [Authorize(Roles = "Admin")]
    [RoutePrefix("DisplayBoard")]
    public class DisplayBoardController : ApiController
    {
        private readonly DisplayBoardService displayBoardService;
        public DisplayBoardController(DisplayBoardService _displayBoardService)
        {
            displayBoardService = _displayBoardService;
        }


        [HttpPost]
        [Route("CreateTemplate")]
        public IHttpActionResult CreateTemplate(Template template)
        {
            try
            {
                displayBoardService.CreateTemplate(template);
                return Ok();
            }
            catch(Exception ex)
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
